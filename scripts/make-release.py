#!/usr/bin/env python3
"""生成可解压运行的安装包；只收清单中的源码，离线依赖必须显式指定。"""
import argparse
import base64
import gzip
import hashlib
import io
import os
import tarfile
import tempfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'emacs-portable/'
# Assign every public file to one of two reviewed manifests. Files created by
# editors, local builds and authentication tools are never discovered recursively.
def manifest(name):
    lines = (ROOT/'scripts'/name).read_text(encoding='utf-8').splitlines()
    return [line for line in lines if line and not line.startswith('#')]

def sources():
    paths = manifest('release-files.txt') + ['payload/'+name for name in manifest('config-files.txt')]
    if len(paths) != len(set(paths)):
        raise ValueError('发行文件清单重复')
    for name in sorted(paths):
        rel = PurePosixPath(name)
        p = ROOT/rel
        if (not rel.parts or rel.is_absolute() or '..' in rel.parts or str(rel) != name
                or any(c in name for c in '*?[]\\') or p.resolve(strict=True) != p or not p.is_file()):
            raise ValueError('不接受的发行文件：'+name)
        yield name, p

def digest(data):
    return hashlib.sha256(data).hexdigest()

def write_release(stage, bundle, public_offline=False):
    items = list(sources())
    snapshot = None
    inner = 'public-offline-packages' if public_offline else 'offline-packages'
    bundle_name = 'deps/'+inner+'.tar.gz'
    if bundle:
        snapshot = bundle.read_bytes()
        pin_file = ROOT/'deps'/(inner+'.sha256')
        pin, name = pin_file.read_text(encoding='ascii').split()
        if name != inner+'.tar.gz' or digest(snapshot) != pin:
            raise ValueError('离线依赖与 '+pin_file.name+' 不符，未生成发行文件。')
        items.append((bundle_name, bundle))
    suffix = 'offline' if bundle else 'source'
    archive = stage/('emacs-portable-'+suffix+'.tar.gz')
    sums = []
    def entry(tar, name, data, mode):
        meta = tarfile.TarInfo(PREFIX+name)
        meta.size, meta.mode, meta.mtime = len(data), mode, 0
        tar.addfile(meta, io.BytesIO(data))
    with archive.open('xb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode='w') as tar:
            for name, p in sorted(items):
                data = snapshot if name == bundle_name else p.read_bytes()
                sums.append(digest(data)+'  '+name)
                mode = 0o755 if name.endswith('.sh') or p.stat().st_mode & 0o111 else 0o644
                entry(tar, name, data, mode)
            entry(tar, 'SHA256SUMS', ('\n'.join(sums)+'\n').encode(), 0o644)
    with tarfile.open(archive) as tar:
        for row in sums:
            sha, name = row.split('  ', 1)
            if digest(tar.extractfile(PREFIX+name).read()) != sha:
                raise ValueError(name)

    # 打包器和用户安装的是同一份 tar，单文件入口复用 install.sh 的全部检查。
    source = archive.read_bytes()
    installer = stage/('emacs-portable-'+suffix+'.sh')
    with tarfile.open(archive) as tar:
        template = tar.extractfile(PREFIX+'scripts/standalone.sh.in').read()
    installer.write_bytes(template.replace(b'@ARCHIVE_SHA256@', digest(source).encode('ascii'))
                          .replace(b'@ARCHIVE_BASE64@', base64.encodebytes(source)))
    installer.chmod(0o755)
    for artifact in (archive, installer):
        checksum = digest(artifact.read_bytes())+'  '+artifact.name+'\n'
        artifact.with_name(artifact.name+'.sha256').write_text(checksum, encoding='ascii')

def build(output, bundle, public_offline=False):
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output) as temp:
        stage = Path(temp)
        write_release(stage, bundle, public_offline)
        created = []
        try:
            for artifact in sorted(stage.iterdir()):
                dest = output/artifact.name
                os.link(artifact, dest)
                created.append(dest)
        except BaseException:
            for dest in created:
                dest.unlink()
            raise
        for dest in created:
            if dest.suffix == '.sha256':
                print(dest.read_text(encoding='ascii'), end='')

if __name__ == '__main__':
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--output', required=True, type=Path)
    group = cli.add_mutually_exclusive_group()
    group.add_argument('--offline-bundle', type=Path, help='个人迁移用的固定快照')
    group.add_argument('--public-offline-bundle', type=Path, help='含上游声明的公开发行快照')
    args = cli.parse_args()
    build(args.output, args.public_offline_bundle or args.offline_bundle,
          public_offline=args.public_offline_bundle is not None)
