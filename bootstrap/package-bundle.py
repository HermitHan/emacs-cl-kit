#!/usr/bin/env python3
"""Build a private migration snapshot or restore a hash-verified offline package bundle."""
import argparse
import gzip
import hashlib
import io
import json
import os
import pathlib
import re
import tarfile

P = pathlib.Path
ROOT = P(__file__).resolve().parents[1]
META = 'bundle-manifest.json'
MAX_SIZE = 256 * 1024 * 1024
REF = dict(row.split('\t') for row in (ROOT/'deps/reference-packages.tsv').read_text().splitlines() if row and not row.startswith('#'))
SUPPLEMENTS = {'compat-30.1.0.1': 'compat', 'which-key-20240620.2145': 'which-key'}
KNOWN = {f'{n}-{v}': n for n, v in REF.items()}
KNOWN.update(SUPPLEMENTS)

def allowed(path):
    p = pathlib.PurePosixPath(path)
    if not path or p.is_absolute() or '..' in p.parts or p.as_posix() != path or len(p.parts) < 2 or p.parts[0] not in KNOWN:
        return False
    if any(t.startswith('.') for t in p.parts[1:]):
        return False
    if p.name.endswith(('.elc','.eln','.fasl','.dylib','.so','.o','.pyc','.class','.exe','.dll','.lock','.sqlite','.sqlite3','.signed','~','-autoloads.el')):
        return False
    if p.name in ('dir', 'archive-contents') or 'gnupg' in p.parts:
        return False
    return True

def tar_add(t, data, name, mode=0o644):
    info = tarfile.TarInfo(name)
    info.size, info.mode = len(data), mode
    t.addfile(info, io.BytesIO(data))

def check_set(files):
    for name, pkg in KNOWN.items():
        if name+'/'+pkg+'-pkg.el' not in files:
            raise ValueError(f'Package description missing: {name}')

def build(ns):
    source, extra, out = ns.packages.resolve(), ns.compat.resolve(), ns.output.resolve()
    if out.exists():
        raise SystemExit('Refusing to replace '+str(out))
    data = {}
    for dirname in sorted(set(KNOWN)-{'compat-30.1.0.1'}):
        d = ns.which_key.resolve() if dirname.startswith('which-key-') else source / dirname
        if not d.is_dir() or d.is_symlink():
            raise SystemExit('Missing source '+str(d))
        for f in sorted(d.rglob('*')):
            name = dirname + '/' + f.relative_to(d).as_posix()
            if f.is_symlink():
                raise SystemExit('Unreviewed symlink: '+name)
            if f.is_file() and allowed(name):
                data[name] = (f.read_bytes(), 0o755 if f.stat().st_mode & 0o111 else 0o644)
    with tarfile.open(extra, 'r:*') as t:
        for m in t:
            if m.isfile() and m.name.startswith('compat-30.1.0.1/') and allowed(m.name):
                data[m.name] = (t.extractfile(m).read(), 0o755 if m.mode & 0o111 else 0o644)
    check_set(data)
    # Only reference ELPA packages listed above are selected (no config, caches, archives).
    private_roots = [os.fsencode(path).rstrip(b'/') + b'/' for path in [P.home(), *ns.reject_prefix]]
    personal = [k for k,(b,_) in data.items() if any(prefix in b for prefix in private_roots)]
    if personal:
        raise SystemExit('Local absolute path in package source: '+', '.join(personal))
    manifest = {k: hashlib.sha256(b).hexdigest() for k,(b,_) in sorted(data.items())}
    with out.open('xb') as fp, gzip.GzipFile(fileobj=fp, filename='', mode='wb', mtime=0) as gz, tarfile.open(fileobj=gz,mode='w') as t:
        tar_add(t, (json.dumps(manifest,sort_keys=True)+'\n').encode(), META)
        for k,(b,mode) in sorted(data.items()):
            tar_add(t,b,k,mode)
    print(f'{len(KNOWN)} source packages / {len(data)} files; {out.stat().st_size} bytes')

def restore(ns):
    dest = ns.output.resolve()
    if dest.exists():
        raise SystemExit('Package target must be new: '+str(dest))
    with tarfile.open(ns.bundle,'r:gz') as t:
        members = t.getmembers()
        if not members or sum(m.size for m in members)>MAX_SIZE or len(members)>10000:
            raise ValueError('Unexpected offline bundle size')
        names = [m.name for m in members]
        if len(set(names))!=len(names) or any(not m.isfile() for m in members) or META not in names:
            raise ValueError('Unexpected member type, missing manifest or duplicate member')
        manifest=json.load(t.extractfile(META))
        if set(manifest)!=set(names)-{META} or not all(allowed(n) for n in manifest):
            raise ValueError('Unrecognized bundle file')
        check_set(manifest)
        # Builtin compat on 30.1+ is part of Emacs. Only install the extra package on 29.
        dest.mkdir(mode=0o700)
        for m in members:
            if m.name==META:
                continue
            data=t.extractfile(m).read()
            if hashlib.sha256(data).hexdigest()!=manifest[m.name]:
                raise ValueError('Damaged package file: '+m.name)
            if ns.emacs_major>=30 and m.name.split('/',1)[0] in SUPPLEMENTS:
                continue
            out=dest/m.name
            out.parent.mkdir(parents=True, exist_ok=True)
            with out.open('xb') as fp: fp.write(data)
            out.chmod(0o755 if m.mode&0o111 else 0o644)
    print('Verified offline package sources.')

a=argparse.ArgumentParser(description=__doc__)
s=a.add_subparsers(dest='op',required=True)
p=s.add_parser('build'); p.add_argument('--reject-prefix', action='append', default=[], help='extra private absolute prefix to reject');p.add_argument('--packages',type=P,required=True);p.add_argument('--compat',type=P,required=True);p.add_argument('--which-key',type=P,required=True);p.add_argument('--output',type=P,required=True)
p=s.add_parser('restore');p.add_argument('--bundle',type=P,required=True);p.add_argument('--output',type=P,required=True);p.add_argument('--emacs-major',type=int,required=True)
ns=a.parse_args()
(build if ns.op=='build' else restore)(ns)
