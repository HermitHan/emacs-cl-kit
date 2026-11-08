#!/usr/bin/env bash
# 安装器内部接口。所有构建均在私有临时目录完成，检查通过后才交付给 staging。
set -euo pipefail
umask 077
mode=build
if [[ "${1:-}" == --check ]]; then mode=check; shift; fi
if [[ $# != 1 || ! -d "$1" ]]; then echo 'usage: packages.sh [--check] CONFIG-DIRECTORY' >&2; exit 2; fi
target=$(cd -- "$1" && pwd -P)
here=$(cd -- "$(dirname -- "$0")" && pwd -P)
repo=$(cd -- "$here/.." && pwd -P)
editor=${EMACS:-emacs}
private=$(mktemp -d "${TMPDIR:-/tmp}/emacs-packages.XXXXXXXX")
trap 'rm -rf -- "$private"' EXIT
mkdir "$private/home"
export HOME="$private/home" XDG_CONFIG_HOME="$private/home/.config" XDG_CACHE_HOME="$private/home/.cache"
export HAN_PKGDEPS="$repo/deps"
version=$("$editor" -Q --batch --eval '(princ (format "%d.%d" emacs-major-version emacs-minor-version))')
dest="$target/elpa-$version"
if [[ "$mode" == check ]]; then
  [[ -d "$dest" && ! -L "$dest" ]] || { echo "缺少可核对的现有包目录：$dest" >&2; exit 1; }
  HAN_PKGACTION=check HAN_PKGDIR="$dest" "$editor" -Q --batch -l "$here/packages.el"
  exit
fi
[[ ! -e "$dest" && ! -L "$dest" ]] || { echo "拒绝替换已有包目录：$dest" >&2; exit 1; }
export HAN_PKGDIR="$private/elpa-$version"
bundle=${EMACS_PORTABLE_PACKAGE_BUNDLE:-}
if [[ -z "$bundle" && -f "$repo/deps/offline-packages.tar.gz" ]]; then bundle="$repo/deps/offline-packages.tar.gz"; fi
if [[ -z "$bundle" && -n "${EMACS_PORTABLE_BUNDLE_URL:-}" ]]; then
  case "$EMACS_PORTABLE_BUNDLE_URL" in
    https://*) ;;
    *) echo "依赖下载地址必须使用 HTTPS。" >&2; exit 1 ;;
  esac
  bundle="$private/offline-packages.tar.gz"
  curl --fail --location --proto '=https' --proto-redir '=https' --connect-timeout 10 \
    --max-time 120 --max-filesize 16777216 --retry 1 --output "$bundle" -- "$EMACS_PORTABLE_BUNDLE_URL"
fi
if [[ -z "$bundle" ]]; then
  echo "正在下载此版本锁定的第三方依赖；首次安装需要网络。" >&2
  python3 "$here/online-packages.py" --output "$HAN_PKGDIR" --emacs-major "${version%%.*}"
else
  [[ -f "$bundle" ]] || { echo "指定的离线依赖文件不存在：$bundle" >&2; exit 1; }
  python3 - "$repo/deps/offline-packages.sha256" "$bundle" <<'PYHASH'
from pathlib import Path
import hashlib, sys
expected=Path(sys.argv[1]).read_text().split()[0]
digest=hashlib.sha256()
with Path(sys.argv[2]).open("rb") as stream:
    for block in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(block)
if digest.hexdigest() != expected:
    raise SystemExit("依赖包 SHA256 与此版本不符；停止安装。")
PYHASH
  echo "固定版本依赖包 SHA256 已验证；用目标 Emacs 生成 autoload。" >&2
  python3 "$here/package-bundle.py" restore --bundle "$bundle" --output "$HAN_PKGDIR" --emacs-major "${version%%.*}"
fi
HAN_PKGACTION=offline "$editor" -Q --batch -l "$here/packages.el"
# TARGET is a private staging directory owned by the caller, never the final live config.
mv -- "$HAN_PKGDIR" "$dest"
