"""安装受管配置，不读取凭据或历史内容。运行入口：仓库根目录的 install.sh。"""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
STATE = "var/portable-install.json"
PREF = "var/slime-default-lisp"
TOP = {".agignore", ".dir-locals.el", "early-init.el", "init.el", "gptel-preferences.md",
       "配置阅读指南.org", "README.md", "LICENSE", "COPYING.org-examples", "test-startup.sh"}
PROGRAMS = (("sbcl", "sbcl"), ("my-lispworks", "my-lispworks"), ("lispworks", "lispworks"),
            ("han-lispworks", "han-lispworks"), ("cmucl", "lisp"), ("ccl", "ccl"))
DIGEST = re.compile(r"[a-f0-9]{64}\Z")


class InstallError(Exception):
    pass


def fail(msg):
    raise InstallError(msg)


def canonical(arg):
    """拒绝参数路径上的符号链接，包括不存在的叶节点的父目录；兼容 macOS 系统临时目录别名。"""
    p = Path(os.path.abspath(os.path.expanduser(arg)))
    if sys.platform == "darwin" and len(p.parts) > 1 and p.parts[1] in ("tmp", "var"):
        alias = Path("/") / p.parts[1]
        physical = Path("/private") / p.parts[1]
        if alias.is_symlink() and alias.resolve() == physical:
            p = physical.joinpath(*p.parts[2:])
    ensure_no_links(p)
    return p


def ensure_no_links(p):
    for component in (p,) + tuple(p.parents):
        if component.is_symlink():
            fail("拒绝通过符号链接读写，请使用独立实体目录：" + str(component))


def rel_allowed(rel):
    parts = PurePosixPath(rel).parts
    return (rel in TOP or
            (len(parts) == 2 and parts[0] == "lisp" and parts[1].endswith(".el")) or
            rel == "site-lisp/README")


def checked_file(base, rel, state=False):
    if not ((state and rel in (STATE, PREF)) or rel_allowed(rel)):
        fail("清单包含非受管路径：" + str(rel))
    if str(PurePosixPath(rel)) != rel or not rel or ".." in PurePosixPath(rel).parts:
        fail("清单含非标准路径：" + rel)
    p = base / rel
    ensure_no_links(p)
    for ancestor in p.parents:
        if ancestor.exists() and not ancestor.is_dir():
            fail("父路径不是目录：" + str(ancestor))
        if ancestor == base:
            break
    if p.exists() and not p.is_file():
        fail("目标不是普通文件：" + str(p))
    return p


def read_optional(p):
    return p.read_bytes() if p.exists() else None


def sha(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None


def encode(obj):
    return (json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def payload():
    base = ROOT / "payload"
    ensure_no_links(base)
    result = {}
    for p in sorted(base.rglob("*")):
        ensure_no_links(p)
        rel = p.relative_to(base).as_posix()
        if p.is_dir():
            continue
        if not p.is_file() or not rel_allowed(rel):
            fail("payload 含有未授权的文件：" + rel)
        result[rel] = p.read_bytes()
    required = {"init.el", "early-init.el", "lisp/init-common-lisp.el"}
    if not required <= set(result):
        fail("安装包不完整，缺少：" + ", ".join(sorted(required - set(result))))
    return result


def registry(data):
    if data is None:
        return {}
    obj = json.loads(data)
    if not isinstance(obj, dict) or obj.get("format") != 1 or not isinstance(obj.get("files"), dict):
        fail("已有安装记录格式不兼容，已停止。")
    files = obj["files"]
    for name, hash_ in files.items():
        if not rel_allowed(name) or not isinstance(hash_, str) or not DIGEST.fullmatch(hash_):
            fail("已有安装记录不合法：" + str(name))
    return files


def detect():
    available = []
    for name, program in PROGRAMS:
        if name == "lispworks":
            program = os.getenv("LISPWORKS") or program
        if shutil.which(program):
            available.append(name)
    return available


def old_preference(target, options):
    pref = read_optional(checked_file(target, PREF, True))
    if pref is not None:
        name = pref.decode().strip()
        if name in options:
            return name, "保留本机上次选择"
    # 首次接管已有配置时，只识别 init.el 里明文、独立的 setq 行；不 eval 旧配置。
    data = read_optional(checked_file(target, "init.el"))
    if data:
        literal = re.search(rb"(?m)^[ \t]*\(setq[ \t]+slime-default-lisp[ \t]+'([A-Za-z0-9-]+)\s*\)[ \t]*(?:;[^\n]*)?$", data)
        if literal and literal.group(1).decode() in options:
            return literal.group(1).decode(), "保留已有配置的默认实现"
    return (("sbcl" if "sbcl" in options else options[0]) if options else None), "本机首个可用实现"


def choose(target, args):
    options = detect()
    default, origin = old_preference(target, options)
    print("检测到的 Lisp 后端：" + (", ".join(options) or "无；可安装编辑器，稍后安装 Lisp 再运行。"), flush=True)
    if args.backend:
        if args.backend not in options:
            fail("--backend 不可用：" + args.backend)
        return args.backend
    if not default or args.non_interactive or args.dry_run or args.timeout == 0:
        return default
    if read_optional(checked_file(target, PREF, True)) == (default + "\n").encode():
        return default
    with contextlib.ExitStack() as stack:
        try:
            tty = stack.enter_context(open("/dev/tty", "r"))
            prompt = stack.enter_context(open("/dev/tty", "w", buffering=1))
        except OSError:
            # 某些容器/沙盒封住 /dev/tty 节点，但已继承的终端描述符仍是正常的。
            if not (sys.stdin.isatty() and sys.stderr.isatty()):
                return default
            tty, prompt = sys.stdin, sys.stderr
        end = time.monotonic() + args.timeout
        print("选择默认 Lisp（可输入编号或名称）：" +
              "  ".join("%d=%s" % (i, x) for i, x in enumerate(options, 1)), file=prompt)
        while True:
            print("默认 %s（%s），回车或 %d 秒超时采用默认：" % (default, origin, args.timeout), end=" ", file=prompt, flush=True)
            ready = select.select([tty], [], [], max(0, end - time.monotonic()))[0]
            if not ready:
                # 丢弃未按回车的残余输入，避免返回调用者后由 shell 执行。
                import termios
                termios.tcflush(tty.fileno(), termios.TCIFLUSH)
                print("", file=prompt)
                return default
            answer = tty.readline().strip()
            if not answer:
                return default
            if answer in options:
                return answer
            if answer.isdigit() and 1 <= int(answer) <= len(options):
                return options[int(answer) - 1]
            print("没有该选项。", file=prompt)


def mode_for(rel, existing=None):
    if existing is not None:
        return existing
    return 0o700 if rel == "test-startup.sh" else (0o600 if rel.startswith("var/") else 0o644)


def atomic_bytes(p, data, mode):
    ensure_no_links(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=str(p.parent), prefix=".portable-tmp-")
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
        os.replace(name, str(p))
    finally:
        if os.path.exists(name):
            os.unlink(name)


def mode_of(p):
    return p.stat().st_mode & 0o7777 if p.exists() else None


def reject_compiled_config(target, wanted):
    """同名 .elc 可能遮蔽新源码。只检查受管模块旁的路径，不遍历或改动用户的包。"""
    compiled = [rel + "c" for rel in wanted
                if rel.endswith(".el") and os.path.lexists(target / (rel + "c"))]
    if compiled:
        fail("发现可能优先于受管源码加载的字节码：\n  " + "\n  ".join(compiled) +
             "\n请改用新的 --target，或先备份并移走以上文件后重试。")


def plan(target, args):
    wanted = payload()
    reject_compiled_config(target, wanted)
    prev = registry(read_optional(checked_file(target, STATE, True)))
    files = {rel: sha(data) for rel, data in wanted.items()}
    conflicts, changes = [], {}
    for rel, data in wanted.items():
        p = checked_file(target, rel)
        current = read_optional(p)
        if current == data:
            continue
        if ((rel in prev and sha(current) != prev[rel]) or (rel not in prev and current is not None)):
            conflicts.append(rel)
        changes[rel] = (current, data, mode_of(p))
    if conflicts and not args.adopt:
        fail("以下文件与安装包不同（或已手动修改/删除）；未写入：\n  " + "\n  ".join(conflicts) +
             "\n建议用独立 --target；可用 --dry-run --adopt 预演，如确实要替换这些文件再显式传 --adopt。")
    if conflicts:
        print("将先备份并接管 %d 个有差异的配置文件：\n  %s" %
              (len(conflicts), "\n  ".join(conflicts)))
    chosen = choose(target, args)
    # 不删除新版不再提供的文件，只停止追踪它们。其余非受管文件始终不动。
    for rel, data in [(STATE, encode({"format": 1, "files": files})),
                      (PREF, (chosen + "\n").encode() if chosen else None)]:
        p = checked_file(target, rel, True)
        current = read_optional(p)
        if data is not None and current != data:
            changes[rel] = (current, data, mode_of(p))
    return wanted, changes, chosen


def package_dir_name():
    emacs = os.getenv("EMACS") or "emacs"
    try:
        out = subprocess.check_output([emacs, "--version"], text=True, stderr=subprocess.STDOUT)
    except (FileNotFoundError, subprocess.CalledProcessError) as e:
        fail("需要可运行的 Emacs；可设置 EMACS=/完整路径/emacs，或只用 --config-only。")
    match = re.search(r"GNU Emacs (\d+)\.(\d+)", out)
    if not match or tuple(map(int, match.groups())) < (29, 1):
        fail("完整安装需要 GNU Emacs 29.1 或更高版本。")
    return "elpa-%s.%s" % match.groups()


def package_action(target, enabled):
    if not enabled:
        return None, None
    name = package_dir_name()
    p = target / name
    ensure_no_links(p)
    if p.exists() and not p.is_dir():
        fail("包路径不是目录：" + str(p))
    return name, ("check" if p.exists() else "stage")


def package_helper(*args):
    helper = ROOT / "bootstrap" / "packages.sh"
    if not helper.is_file():
        fail("安装包缺少 bootstrap/packages.sh。")
    result = subprocess.run(["bash", str(helper)] + [str(x) for x in args])
    if result.returncode:
        if args[0] == "--check":
            fail("当前包环境未通过兼容性检查，未修改。推荐使用新的 --target 目录；--config-only 可显式跳过依赖验证。")
        fail("依赖准备失败；没有写入目标配置。")


def startup_preflight(pkgdir, wanted, chosen, check_packages=False):
    """启动真正的配置模板；既有包也只在副本验证，不执行目标的 custom.el 或会话。"""
    verifier = ROOT / "tests/verify-startup.el"
    if not verifier.is_file():
        fail("安装包缺少离线启动预检脚本。")

    def reject_links(directory, names):
        for name in names:
            p = Path(directory) / name
            if p.is_symlink() or not (p.is_file() or p.is_dir()):
                fail("无法隔离复制包含链接或特殊文件的包：" + str(p))
        return []

    with tempfile.TemporaryDirectory(prefix="emacs-install-check-", dir="/tmp") as temp:
        home = Path(temp).resolve()
        cfg = home / ".emacs.d"
        for rel, data in wanted.items():
            atomic_bytes(cfg / rel, data, mode_for(rel))
        if chosen:
            atomic_bytes(cfg / PREF, (chosen + "\n").encode(), 0o600)
        dest = cfg / pkgdir.name
        dest.mkdir()
        # package.el 从各包的描述文件发现包，不需要复制软件源索引、GnuPG 目录等。
        for package in pkgdir.iterdir():
            if package.name in ("archives", "gnupg") or package.name.startswith("."):
                continue
            if package.is_symlink():
                fail("无法预检含符号链接的包目录：" + str(package))
            if package.is_dir() and any(package.glob("*-pkg.el")):
                shutil.copytree(package, dest / package.name, ignore=reject_links)
        if check_packages:
            package_helper("--check", cfg)
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home/".config"),
                   XDG_CACHE_HOME=str(home/".cache"), XDG_DATA_HOME=str(home/".local/share"))
        for key in ("HAN_TEST_TARGET", "HAN_EXPECT_DEFAULT", "EMACSLOADPATH"):
            env.pop(key, None)
        print("在临时 HOME 中验证完整启动、CL、快捷键和 gptel（不联网、不加载原会话）。", flush=True)
        result = subprocess.run([os.getenv("EMACS") or "emacs", "-Q", "--batch", "-l", str(verifier)],
                                cwd=str(home), env=env, timeout=160)
        if result.returncode:
            fail("正式配置启动预检失败；目标目录未改动。")


@contextlib.contextmanager
def locked(backup_root):
    ensure_no_links(backup_root)
    backup_root.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock = backup_root / ".install.lock"
    ensure_no_links(lock)
    with open(lock, "a") as fp:
        try:
            fcntl.flock(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            fail("另一个安装或恢复进程正在运行。")
        yield


def restore_data(target, rel, data, mode):
    p = checked_file(target, rel, True)
    if data is None:
        if p.exists():
            p.unlink()
    else:
        atomic_bytes(p, data, mode)


def ensure_unchanged(target, changes):
    for rel, (before, after, mode) in changes.items():
        p = checked_file(target, rel, True)
        if read_optional(p) != before or mode_of(p) != mode:
            fail("安装期间文件有改动，停止：" + rel)


def commit(target, backup_root, wanted, changes, staged_pkg):
    # 先把全部旧内容和事务清单写进独立私有目录，再触碰用户目标。
    ensure_unchanged(target, changes)
    reject_compiled_config(target, wanted)
    backup = Path(tempfile.mkdtemp(prefix=time.strftime("%Y%m%d-%H%M%S-"), dir=str(backup_root)))
    installer = os.environ.get("HAN_INSTALLER_FILE", "./install.sh")
    if installer:
        restore_command = ["bash", installer]
    else:
        # 管道安装没有可再次运行的脚本路径。保留本版本的还原程序，断网也可以使用。
        helper = backup / "restore.py"
        atomic_bytes(helper, Path(__file__).read_bytes(), 0o600)
        restore_command = ["python3", str(helper)]
    records = {}
    for rel, (before, after, mode) in changes.items():
        if before is not None:
            atomic_bytes(backup / "files" / rel, before, 0o600)
        records[rel] = {"before": sha(before), "after": sha(after),
                        "mode": mode, "after_mode": mode_for(rel, mode)}
    atomic_bytes(backup / "transaction.json", encode({"format": 1, "target": str(target), "files": records,
                 "package_dir_added": staged_pkg.name if staged_pkg else None}), 0o600)
    created_target = not target.exists()
    done, package = [], None
    try:
        target.mkdir(mode=0o700, exist_ok=True)
        if staged_pkg:
            dest = target / staged_pkg.name
            ensure_no_links(dest)
            if dest.exists():
                fail("准备期间已有包目录出现：" + str(dest))
            staged_pkg.rename(dest)
            package = dest
        for rel, (before, after, mode) in changes.items():
            p = checked_file(target, rel, True)
            if read_optional(p) != before or mode_of(p) != mode:
                fail("配置文件同时被其他程序更改：" + rel)
            installed_mode = records[rel]["after_mode"]
            atomic_bytes(p, after, installed_mode)
            done.append(rel)
            if p.read_bytes() != after or mode_of(p) != installed_mode:
                fail("安装内容或权限核验失败：" + rel)
        reject_compiled_config(target, wanted)
    except BaseException:
        for rel in reversed(done):
            before, _, mode = changes[rel]
            restore_data(target, rel, before, mode)
        if package:
            package.rename(staged_pkg)
        if created_target:
            for folder in (target / "var", target / "lisp", target / "site-lisp", target):
                if folder.is_dir():
                    try:
                        folder.rmdir()
                    except OSError:
                        pass
        raise
    print("已写入并核验 %d 个配置/状态文件。恢复点：%s" % (len(changes), backup))
    print("要恢复本次变更：" + shlex.join(restore_command + ["--target", str(target), "--restore", str(backup)]))


def restore(target, backup_root, args):
    backup = canonical(args.restore)
    if backup.parent != backup_root:
        fail("恢复点必须位于该目标的备份目录：" + str(backup_root))
    manifest = backup / "transaction.json"
    ensure_no_links(manifest)
    txn = json.loads(manifest.read_bytes())
    if txn.get("format") != 1 or txn.get("target") != str(target) or not isinstance(txn.get("files"), dict):
        fail("恢复点与目标不匹配。")
    changes = {}
    for rel, row in txn["files"].items():
        p = checked_file(target, rel, True)
        current = read_optional(p)
        mode = row["mode"]
        if ((row["before"] is None) != (mode is None)
                or (mode is not None and (type(mode) is not int or not 0 <= mode <= 0o7777))):
            fail("备份权限记录无效：" + rel)
        # 旧事务没有 after_mode：更新保留原权限，新建文件使用该路径对应的安装默认值。
        installed_mode = row.get("after_mode", mode_for(rel, mode))
        if type(installed_mode) is not int or not 0 <= installed_mode <= 0o7777:
            fail("安装权限记录无效：" + rel)
        if current is None or sha(current) != row["after"] or mode_of(p) != installed_mode:
            fail("安装后该文件内容或权限发生变动；拒绝覆盖：" + rel)
        previous = None
        if row["before"] is not None:
            bfile = checked_file(backup / "files", rel, True)
            previous = bfile.read_bytes()
            if sha(previous) != row["before"]:
                fail("备份内容记录无效：" + rel)
        changes[rel] = (current, previous, mode, installed_mode)
    if args.dry_run:
        print("预演恢复 %d 个受管文件，不写入。" % len(changes))
        return
    done = []
    with locked(backup_root):
        try:
            for rel, (current, previous, mode, newmode) in changes.items():
                p = checked_file(target, rel, True)
                if read_optional(p) != current or mode_of(p) != newmode:
                    fail("恢复期间目标发生改动：" + rel)
                restore_data(target, rel, previous, mode)
                done.append(rel)
        except BaseException:
            for rel in reversed(done):
                current, _, _, newmode = changes[rel]
                restore_data(target, rel, current, newmode)
            raise
    print("已恢复 %d 个文件。ELPA 包、非受管文件及目录保留。" % len(changes))


def main():
    parser = argparse.ArgumentParser(description="安装可移植 Emacs 配置。新机默认准备依赖；当前配置不会被无提示覆盖。")
    parser.add_argument("--target", default="~/.emacs.d", metavar="DIR")
    parser.add_argument("--backend", metavar="NAME", help="指定已检测到的默认 CL 实现")
    parser.add_argument("--timeout", type=int, default=10, metavar="SEC", help="交互选择最长等待秒数，默认 10")
    parser.add_argument("--non-interactive", action="store_true", help="不等待输入")
    parser.add_argument("--adopt", action="store_true", help="允许备份后覆盖有差异的受管文件")
    parser.add_argument("--dry-run", action="store_true", help="仅检查配置并显示计划，不下载或写文件")
    parser.add_argument("--config-only", action="store_true", help="仅复制配置，显式跳过包安装和验证")
    parser.add_argument("--restore", metavar="BACKUP", help="只恢复指定事务涉及的配置；不卸载包")
    args = parser.parse_args()
    if sys.version_info < (3, 8):
        fail("需要 Python >= 3.8。")
    if not 0 <= args.timeout <= 300:
        fail("--timeout 必须在 0 到 300 秒之间。")
    target = canonical(args.target)
    if target in (Path("/"), Path.home().resolve()) or target == ROOT or ROOT in target.parents or target in ROOT.parents:
        fail("请选择独立的 Emacs 配置目录。")
    if target.exists() and not target.is_dir():
        fail("目标不是目录：" + str(target))
    backup_root = target.parent / (target.name + ".portable-backups")
    if args.restore:
        return restore(target, backup_root, args)
    wanted, changes, chosen = plan(target, args)
    name, action = package_action(target, not args.config_only)
    action_msg = {"check": "核验现有包（不改动）", "stage": "临时目录准备依赖，成功后安装", None: "跳过（--config-only）"}
    print("%s：%s；改变文件 %d；默认实现 %s；包：%s。" % (
          "预演" if args.dry_run else "目标", target, len(changes), chosen or "未设置", action_msg[action]), flush=True)
    if any((target / rel).is_file() for rel in ("history", ".session", "recentf", ".emacs.desktop")):
        print("本目录已有旧历史/会话文件，将原样保留；新版从 var/ 读取，想接续原历史需另行迁移。")
    override = os.getenv("SLIME_DEFAULT_LISP")
    if override and override != chosen:
        print("注意：若启动 Emacs 时仍设置 SLIME_DEFAULT_LISP=%s，环境变量优先于安装器保存的偏好。" % override)
    if args.dry_run:
        return
    if action == "check":
        startup_preflight(target / name, wanted, chosen, check_packages=True)
    if not changes and action != "stage":
        reject_compiled_config(target, wanted)
        print("已是相同配置，无需更新。")
        return
    os.umask(0o077)
    with locked(backup_root), tempfile.TemporaryDirectory(prefix=".emacs-portable-stage-", dir=str(target.parent)) as tmp:
        work = Path(tmp)
        staged_pkg = None
        if action == "stage":
            for rel, data in wanted.items():
                atomic_bytes(work / rel, data, mode_for(rel))
            package_helper(work)
            staged_pkg = work / name
            if staged_pkg.is_symlink() or not staged_pkg.is_dir():
                fail("依赖准备未生成所需包目录：" + name)
            startup_preflight(staged_pkg, wanted, chosen)
        commit(target, backup_root, wanted, changes, staged_pkg)


if __name__ == "__main__":
    try:
        main()
    except (InstallError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as e:
        print("安装器：" + str(e), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n已取消。", file=sys.stderr)
        sys.exit(130)
