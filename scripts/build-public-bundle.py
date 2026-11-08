#!/usr/bin/env python3
"""Build the public offline package archive from hash-locked public inputs (Python 3.8+)."""
import argparse
import concurrent.futures
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import runpy
import subprocess
import tarfile
import tempfile
from urllib.parse import urlsplit
import wave

ROOT = Path(__file__).resolve().parents[1]
ONLINE = runpy.run_path(str(ROOT / "bootstrap" / "online-packages.py"))
# The omitted legacy xref is used only by CLISP. SBCL and LispWorks use
# their own implementations. The remaining exclusions are explained in
# docs/third-party-distribution.md and the package licenses travel with the files.
OMIT = {
    ("haskell-mode", "logo.svg"),
    ("osx-location", "EmacsLocationHelper"),
    ("psci", "psci-dev.el"),
    ("slime", "xref.lisp"),
    ("switch-window", "switch-window-mvborder.el"),
}


def keep(package, name):
    return not (name.endswith((".info", ".gif", ".wav")) or (package, name) in OMIT
                or (package == "company" and name.startswith("images/"))
                or (package in ("purescript-mode", "rspec-mode") and name.startswith("snippets/")))


def checksum(data):
    return hashlib.sha256(data).hexdigest()


def check_path(name):
    path = PurePosixPath(name)
    if (not name or path.is_absolute() or path.as_posix() != name
            or any(part.startswith(".") for part in path.parts)):
        raise ValueError("Invalid package-relative path: " + name)


def verified(data, sha, size):
    if len(data) != size or checksum(data) != sha:
        raise ValueError("Downloaded or cached file differs from lock: " + sha)
    return data


def fetch(cache, sha, size, urls, downloader=None):
    if not re.fullmatch(r"[a-f0-9]{64}", sha) or not 0 < size < 256 * 1024**2:
        raise ValueError("Invalid download size or SHA-256")
    cached = cache / sha
    if cached.exists():
        return verified(cached.read_bytes(), sha, size)
    with tempfile.TemporaryDirectory(dir=str(cache)) as tmp:
        scratch = Path(tmp)
        staged = scratch / "download"
        if downloader:
            staged.write_bytes(verified(downloader(scratch), sha, size))
        else:
            for url in urls:
                if urlsplit(url).scheme != "https":
                    raise ValueError("Expected an HTTPS source: " + url)
                result = subprocess.run(["curl", "-q", "-fLsS", "--proto", "=https",
                                         "--proto-redir", "=https", "--retry", "2",
                                         "--max-time", "180", "--max-filesize", str(size + 1),
                                         "-o", str(staged), "--", url])
                if result.returncode == 0 and checksum(staged.read_bytes()) == sha:
                    break
            else:
                raise ValueError("No matching public download for " + sha)
        data = verified(staged.read_bytes(), sha, size)
        staged.replace(cached)
        return data


def supplemental_file(spec, cache):
    urls = spec.get("urls") or [spec["url"]]
    if "member" not in spec:
        return fetch(cache, spec["sha256"], spec["bytes"], urls)
    archive = fetch(cache, spec["archive_sha256"], spec["archive_bytes"], urls)
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        entry = tar.getmember(spec["member"])
        if not entry.isfile() or entry.size != spec["bytes"]:
            raise ValueError("Unexpected supplemental archive member: " + entry.name)
        return verified(tar.extractfile(entry).read(), spec["sha256"], spec["bytes"])


def tone(period, bursts):
    """Make an original PCM triangle-wave chime using only integer arithmetic."""
    rate = 16000
    pcm = bytearray()
    for duration in bursts:
        for i in range(duration):
            phase = i % period
            triangle = period - 4 * abs(phase - period // 2)
            envelope = min(80, i, duration - i)
            sample = (triangle * 60 * envelope) // 80
            pcm.extend(sample.to_bytes(2, "little", signed=True))
        pcm.extend(bytes(rate // 10 * 2))
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        wav.writeframes(bytes(pcm))
    return out.getvalue()


def collect(package, spec, notices, cache):
    folder = package + "-" + spec["version"]
    fetch_package = lambda scratch: ONLINE["fetch_archive"](package, spec, scratch)
    raw = fetch(cache, spec["sha256"], spec["bytes"], spec["urls"], fetch_package)
    files = {}
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:") as tar:
        for name in spec["files"]:
            if not keep(package, name):
                continue
            member = tar.getmember(folder + "/" + name)
            if not member.isfile() or member.size > len(raw):
                raise ValueError("Invalid source member: " + member.name)
            files[name] = (tar.extractfile(member).read(), bool(member.mode & 0o111))
    for notice in notices:
        name = notice["path"]
        check_path(name)
        data = supplemental_file(notice, cache)
        if name in files and files[name][0] != data:
            raise ValueError("Conflicting supplemental file: " + folder + "/" + name)
        files[name] = (data, False)
    if package == "switch-window":
        files["switch-window-mvborder.el"] = ((ROOT / "scripts/offline/switch-window-mvborder.el").read_bytes(), False)
        files["COPYING.emacs-cl-kit"] = ((ROOT / "payload/COPYING.org-examples").read_bytes(), False)
    if package == "org-pomodoro":
        for name, period, bursts in [("bell", 32, [3200]), ("bell_multiple", 32, [2400, 3200]),
                                     ("tick", 16, [320])]:
            files["resources/" + name + ".wav"] = (tone(period, bursts), False)
    return {folder + "/" + name: value for name, value in files.items()}


def add_entry(tar, name, data, executable=False):
    info = tarfile.TarInfo(name)
    info.size = len(data)
    info.mode = 0o755 if executable else 0o644
    tar.addfile(info, io.BytesIO(data))


def build(cache, output):
    packages = ONLINE["checked_lock"]()
    notices = json.loads((ROOT / "deps/public-offline-notices.json").read_text())
    if not set(notices).issubset(packages):
        raise ValueError("Notices refer to unknown packages")
    cache.mkdir(parents=True, exist_ok=True)
    files = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [pool.submit(collect, name, spec, notices.get(name, []), cache)
                for name, spec in packages.items()]
        for job in concurrent.futures.as_completed(jobs):
            files.update(job.result())
    manifest = {name: checksum(data) for name, (data, _) in files.items()}
    with tempfile.TemporaryDirectory(dir=str(output.parent)) as tmp:
        staged = Path(tmp) / "archive"
        with staged.open("wb") as raw, gzip.GzipFile(filename="", mode="wb", fileobj=raw, compresslevel=9, mtime=0) as gz:
            with tarfile.open(fileobj=gz, mode="w") as tar:
                add_entry(tar, "bundle-manifest.json", (json.dumps(manifest, sort_keys=True) + "\n").encode())
                for name, (data, executable) in sorted(files.items()):
                    add_entry(tar, name, data, executable)
        # Publish atomically and never replace an existing archive.
        os.link(staged, output)
    print("{} packages, {} files, SHA-256 {}".format(len(packages), len(files), checksum(output.read_bytes())))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True, help="Content-addressed public download cache.")
    parser.add_argument("--output", type=Path, required=True, help="New archive file in an existing directory.")
    args = parser.parse_args()
    build(args.cache, args.output)
