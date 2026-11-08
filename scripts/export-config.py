#!/usr/bin/env python3
"""维护工具：从已审查的原始 Emacs 配置生成一个 *新* 源码树，用 diff 审查后再移植。

只导出 config-files.txt 中明确列出的文件。不会同步回本机、递归复制目录或更新已有树。
发布仓库的 payload/ 可以包含移植后的独立修改，切勿用原始树覆盖它。
"""
import argparse
import re
from pathlib import Path
from pathlib import PurePosixPath
import shutil

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "scripts" / "config-files.txt"
DISALLOWED_ROOTS = {".cache", ".git", ".github", "var", "eln-cache", "custom.el", "elpa"}
LITERAL_SECRETS = re.compile(
    rb"-----BEGIN (?:[A-Z ]* )?PRIVATE KEY-----|"
    rb"\b(?:github_pat_[A-Za-z0-9_]{50,}|gh[pousr]_[A-Za-z0-9_]{30,}|sk-(?:proj-)?[A-Za-z0-9_-]{32,})\b"
)


def reviewed_files():
    """白名单按文件名列出。只接受相对 POSIX 路径，不接受通配符、重复项或状态目录。"""
    relative = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        p = PurePosixPath(line)
        if (p.is_absolute() or str(p) != line or not p.parts or ".." in p.parts
                or any(c in line for c in "*?[]\\")
                or p.parts[0] in DISALLOWED_ROOTS or p.parts[0].startswith("elpa-")
                or line in relative):
            raise ValueError(f"清单中有不适合导出的路径：{line}")
        relative.append(line)
    if not relative:
        raise ValueError("清单不能为空")
    return relative


def export(source, output):
    """先读完并检查所有源文件，再一次性向新目录写入；遇到已有目录即退出。"""
    if source.is_symlink():
        raise ValueError("源目录是符号链接，请显式指定真实路径")
    source = source.resolve(strict=True)
    if not source.is_dir():
        raise ValueError("源不是目录")
    output = output.absolute()
    resolved = output.resolve(strict=False)
    if resolved == source or source in resolved.parents:
        raise ValueError("输出必须在现用配置目录外")
    contents = {}
    for rel in reviewed_files():
        path = source / rel
        if path.resolve(strict=True) != path or not path.is_file():
            raise ValueError(f"拒绝链接或非普通文件：{rel}")
        data = path.read_bytes()
        data.decode("utf-8")
        if b"\x00" in data or LITERAL_SECRETS.search(data):
            raise ValueError(f"文件含二进制内容或疑似凭据，请人工检查：{rel}")
        contents[rel] = data
    # 已存在的目录（包括空目录和链接）不可作为目的地，防止覆盖仓库的移植修改。
    output.mkdir(mode=0o755)
    try:
        for rel, data in contents.items():
            path = output / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open("xb") as handle:
                handle.write(data)
            path.chmod(0o755 if rel == "test-startup.sh" else 0o644)
            if path.read_bytes() != data:
                raise OSError(f"导出校验失败：{rel}")
    except BaseException:
        shutil.rmtree(output)
        raise
    print(f"已按白名单导出并逐文件核对 {len(contents)} 个 UTF-8 源文件。")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path.home() / ".emacs.d")
    parser.add_argument("--output", type=Path, required=True, help="必须是尚不存在、父目录已存在的新路径")
    args = parser.parse_args()
    try:
        export(args.source.expanduser(), args.output.expanduser())
    except (OSError, ValueError) as err:
        parser.exit(1, f"未导出：{err}\n")


if __name__ == "__main__":
    main()
