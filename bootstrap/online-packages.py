#!/usr/bin/env python3
"""Install the locked public ELPA archives into a new, isolated package directory."""
import argparse
import concurrent.futures
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import tempfile
import time
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
HOSTS = {"elpa.gnu.org", "elpa.nongnu.org", "raw.githubusercontent.com",
         "cdn.jsdelivr.net", "mirrors.sjtug.sjtu.edu.cn"}
SUPPLEMENTS = {"which-key", "compat"}  # Supplied by Emacs 30 and later.
MAX_ARCHIVE = 16 * 1024 * 1024


def checked_lock():
    lock = json.loads((ROOT / "deps" / "online-packages.json").read_text())
    if lock["format"] != 1:
        raise ValueError("Unknown archive lock format")
    reference = dict(row.split("\t") for row in (ROOT / "deps" / "reference-packages.tsv")
                     .read_text().splitlines() if row and not row.startswith("#"))
    reference.update({"which-key": "20240620.2145", "compat": "30.1.0.1"})
    packages = lock["packages"]
    if {name: spec["version"] for name, spec in packages.items()} != reference:
        raise ValueError("Archive lock does not match the reference package versions")
    for name, spec in packages.items():
        files = spec["files"]
        if (not re.fullmatch(r"[a-zA-Z0-9+-]+", name)
                or not re.fullmatch(r"[0-9.]+", spec["version"])
                or not re.fullmatch(r"[0-9a-f]{40}", spec["commit"])
                or not re.fullmatch(r"[0-9a-f]{64}", spec["sha256"])
                or not 0 < spec["bytes"] <= MAX_ARCHIVE
                or files != sorted(set(files)) or name + "-pkg.el" not in files):
            raise ValueError("Invalid archive lock entry: " + name)
        for filename in files:
            parts = PurePosixPath(filename)
            if (parts.is_absolute() or parts.as_posix() != filename
                    or any(part.startswith(".") for part in parts.parts)):
                raise ValueError("Invalid locked path: " + filename)
        if not spec["urls"]:
            raise ValueError("No public source for " + name)
        for url in spec["urls"]:
            source = urlsplit(url)
            if source.scheme != "https" or source.netloc not in HOSTS or source.query or source.fragment:
                raise ValueError("Invalid source for " + name)
    return packages


def fetch_archive(name, spec, scratch):
    path = scratch / (name + ".tar")
    sources = list(spec["urls"])
    errors = {}
    for attempt in range(3):
        retry = []
        for url in sources:
            command = ["curl", "-q", "--fail", "--silent", "--show-error", "--location",
                       "--proto", "=https", "--proto-redir", "=https", "--connect-timeout", "10",
                       "--max-time", "600", "--speed-time", "60", "--speed-limit", "128",
                       "--retry", "1", "--max-filesize", str(spec["bytes"] + 1),
                       "--output", str(path), "--", url]
            result = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            # Some dual-stack networks reset the IPv4 TLS connection even though
            # the same archive is available over IPv6. Try that route once
            # before moving to the next checksum-equivalent mirror.
            if result.returncode == 35:
                result = subprocess.run(command[:2] + ["--ipv6"] + command[2:],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            host = urlsplit(url).hostname
            if result.returncode:
                errors[host] = result.stderr.decode("utf-8", "replace").strip()
                # Retry interrupted connections after trying the independent, pinned mirrors.
                if result.returncode in (6, 7, 18, 28, 35, 52, 55, 56, 92):
                    retry.append(url)
                continue
            if path.stat().st_size == spec["bytes"]:
                data = path.read_bytes()
                if hashlib.sha256(data).hexdigest() == spec["sha256"]:
                    return data
            errors[host] = "archive size or SHA-256 differs from the lock"
        if not retry or attempt == 2:
            break
        time.sleep(1 << attempt)
        sources = retry
    details = " | ".join(host + ": " + error for host, error in errors.items())
    raise ValueError(name + " (" + details + ")")


def install_archive(name, spec, scratch, package_dir):
    data = fetch_archive(name, spec, scratch)
    folder = name + "-" + spec["version"]
    expected = {folder + "/" + filename for filename in spec["files"]}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:") as archive:
        for member in archive:
            if member.name not in expected:
                continue
            if not member.isfile() or member.size > len(data):
                raise ValueError("Invalid expected archive member: " + member.name)
            destination = package_dir / member.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            with destination.open("xb") as out:
                out.write(archive.extractfile(member).read())
            destination.chmod(0o755 if member.mode & 0o111 else 0o644)
            expected.remove(member.name)
        if expected:
            raise ValueError(name + " archive is missing " + min(expected))


def install(output, major):
    packages = checked_lock()
    if major >= 30:
        packages = {name: spec for name, spec in packages.items() if name not in SUPPLEMENTS}
    if os.path.lexists(output):
        raise ValueError("Package target already exists: " + str(output))
    with tempfile.TemporaryDirectory(prefix="public-packages-", dir=str(output.parent)) as temp:
        scratch = Path(temp)
        package_dir = scratch / "packages"
        package_dir.mkdir(mode=0o700)
        print("Fetching {} pinned public ELPA archives…".format(len(packages)), file=sys.stderr, flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            jobs = [pool.submit(install_archive, name, spec, scratch, package_dir)
                    for name, spec in packages.items()]
            try:
                for count, job in enumerate(concurrent.futures.as_completed(jobs), start=1):
                    job.result()
                    if count % 50 == 0:
                        print("Verified {}/{} archives".format(count, len(jobs)), file=sys.stderr, flush=True)
            except BaseException:
                for job in jobs:
                    job.cancel()
                raise
        package_dir.rename(output)
    print("Installed {} SHA-256 verified public archives.".format(len(packages)), file=sys.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--emacs-major", required=True, type=int)
    args = parser.parse_args()
    try:
        install(args.output.absolute(), args.emacs_major)
    except (OSError, ValueError, tarfile.TarError) as exc:
        sys.exit("Public package installation failed: " + str(exc))
