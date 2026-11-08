#!/usr/bin/env bash
# macOS Bash 3.2 和 Linux 均可用；文件校验、备份及事务使用 Python 标准库。
set -eu
dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
if ! command -v python3 >/dev/null 2>&1; then
    echo "需要 Python 3.8 或更新版本，请先安装 python3。" >&2
    exit 1
fi
exec python3 "$dir/bootstrap/configure.py" "$@"
