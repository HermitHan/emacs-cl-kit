"""安装器隔离端到端测试；依赖阶段用可控的小包替身，真正的包安装另做集成测试。"""
import contextlib
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

SRC = Path(__file__).resolve().parents[1]


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.repo, self.target = self.root / 'kit', self.root / 'target with space'
        (self.repo / 'bootstrap').mkdir(parents=True)
        (self.repo / 'tests').mkdir()
        (self.repo / 'tests/verify-startup.el').write_text(';; isolated startup test double\n')
        (self.repo / 'payload/lisp').mkdir(parents=True)
        self.payload = self.repo / 'payload'
        (self.payload / 'init.el').write_text(';; portable\n')
        (self.payload / 'early-init.el').write_text(';; early\n')
        (self.payload / 'lisp/init-common-lisp.el').write_text(';; portable CL\n')
        shutil.copy2(SRC / 'install.sh', self.repo)
        shutil.copy2(SRC / 'bootstrap/configure.py', self.repo / 'bootstrap')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name, src in [('python3', sys.executable), ('bash', '/bin/bash'), ('dirname', shutil.which('dirname')),
                          ('mkdir', '/bin/mkdir')]:
            (self.bin / name).symlink_to(src)
        for prog in ['emacs', 'sbcl', 'my-lispworks']:
            self.exe(prog, 'if [ "$1" = "--version" ]; then echo "GNU Emacs 30.1"; else [ "${FAKE_FAIL_STARTUP:-0}" = 0 ]; fi' if prog == 'emacs' else 'exit 0')
        (self.repo/'bootstrap/packages.sh').write_text(
            'set -eu\nif [[ "$1" == --check ]]; then [[ -f "$2/elpa-30.1/fixture-1/fixture-pkg.el" ]]; exit; fi\n'
            '[[ -f "$1/init.el" ]]\nmkdir -p "$1/elpa-30.1/fixture-1"\n: > "$1/elpa-30.1/working"\n: > "$1/elpa-30.1/fixture-1/fixture-pkg.el"\n'
            '[[ ${FAKE_FAIL_PACKAGES:-0} == 0 ]]\n')
        self.env = dict(os.environ, HOME=str(self.root), PATH=str(self.bin))
        for key in ('LISPWORKS', 'SLIME_DEFAULT_LISP', 'EMACS'):
            self.env.pop(key, None)

    def exe(self, name, body):
        f = self.bin / name
        f.write_text('#!/bin/sh\n' + body + '\n')
        f.chmod(0o755)

    def run_installer(self, *args, ok=True, env=None):
        result = subprocess.run([str(self.repo / 'install.sh'), '--target', str(self.target),
                                 '--non-interactive', *args], env=(env or self.env), cwd=self.root,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=10)
        self.assertEqual(result.returncode == 0, ok, result.stdout)
        return result.stdout

    def test_piped_release_requires_complete_stream_and_restores_offline(self):
        release = self.root / 'release'
        subprocess.run([sys.executable, str(SRC / 'scripts/make-release.py'), '--output', str(release)],
                       check=True, stdout=subprocess.DEVNULL)
        script = (release / 'emacs-portable-source.sh').read_bytes()
        command = ['bash', '-s', '--', '--target', str(self.target), '--non-interactive', '--config-only']

        # The payload and Python source have arrived, but the final shell line has not.
        partial = script.rstrip(b'\n').rsplit(b'\n', 1)[0] + b'\n'
        rejected = subprocess.run(command, input=partial, cwd=self.root, env=self.env, capture_output=True)
        self.assertNotEqual(rejected.returncode, 0)
        self.assertFalse(self.target.exists())

        installed = subprocess.run(command, input=script, cwd=self.root, env=self.env, capture_output=True, check=True)
        self.assertTrue((self.target / 'init.el').is_file())
        prefix = '要恢复本次变更：'
        restore = next(line[len(prefix):] for line in installed.stdout.decode().splitlines() if line.startswith(prefix))
        shutil.rmtree(release)
        subprocess.run(shlex.split(restore), cwd=self.root, env=self.env, check=True, stdout=subprocess.DEVNULL)
        self.assertFalse((self.target / 'init.el').exists())

    def backup(self):
        root = self.root / (self.target.name + '.portable-backups')
        return sorted(x for x in root.iterdir() if x.is_dir())[-1]

    def test_public_release_rejects_private_snapshot_even_when_renamed(self):
        for directory in ('scripts', 'deps'):
            (self.repo/directory).mkdir()
        scripts = self.repo/'scripts'
        shutil.copy2(SRC/'scripts/make-release.py', scripts)
        for manifest in ('config-files.txt', 'release-files.txt'):
            (scripts/manifest).write_text('')
        private = self.repo/'public-offline-packages.tar.gz'
        private.write_bytes(b'private test fixture')
        for name, content in [('public-offline-packages', b'public test fixture'),
                              ('offline-packages', private.read_bytes())]:
            (self.repo/'deps'/(name+'.sha256')).write_text(
                hashlib.sha256(content).hexdigest()+'  '+name+'.tar.gz\n')
        dist = self.root/'dist'
        result = subprocess.run([sys.executable, str(scripts/'make-release.py'),
                                 '--output', str(dist), '--public-offline-bundle', str(private)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('public-offline-packages.sha256', result.stderr)
        self.assertEqual(list(dist.iterdir()), [])

    def test_minimum_supported_emacs(self):
        for version in ('28.2', '29.0'):
            with self.subTest(version=version):
                self.exe('emacs', 'echo "GNU Emacs ' + version + '"')
                self.assertIn('29.1', self.run_installer('--dry-run', ok=False))
                self.assertFalse(self.target.exists())
        self.exe('emacs', 'echo "GNU Emacs 29.1"')
        self.run_installer('--dry-run')
        self.assertFalse(self.target.exists())

    def test_dry_run_and_fresh_install_repeat(self):
        self.run_installer('--dry-run')
        self.assertFalse(self.target.exists())
        self.assertFalse((self.root / (self.target.name + '.portable-backups')).exists())
        self.run_installer()
        self.assertTrue((self.target/'elpa-30.1/working').is_file())
        pref = self.target/'var/slime-default-lisp'
        self.assertEqual(pref.read_text(), 'sbcl\n')
        manifest = self.target/'var/portable-install.json'
        before = (pref.stat().st_mtime_ns, manifest.stat().st_mtime_ns, self.backup())
        self.assertIn('无需更新', self.run_installer())
        self.assertEqual(before, (pref.stat().st_mtime_ns, manifest.stat().st_mtime_ns, self.backup()))

    def test_old_default_adopt_and_restore_preserve_unmanaged(self):
        self.target.mkdir()
        (self.target/'init.el').write_text("(setq slime-default-lisp 'my-lispworks)\n")
        for name in ('custom.el', 'history', 'var/session', '.cache/gptel-openai/private', 'elpa-29.1/sample'):
            p = self.target / name
            p.parent.mkdir(parents=True,exist_ok=True)
            p.write_text('sentinel')
        self.run_installer(ok=False)
        self.assertIn('\n  init.el\n', self.run_installer('--adopt', '--dry-run'))
        self.assertFalse((self.target/'early-init.el').exists())
        self.run_installer('--adopt')
        self.assertEqual((self.target/'var/slime-default-lisp').read_text(), 'my-lispworks\n')
        backup = self.backup()
        self.run_installer('--restore', str(backup), '--dry-run')
        self.assertEqual((self.target/'init.el').read_text(), ';; portable\n')
        self.run_installer('--restore', str(backup))
        self.assertEqual((self.target/'init.el').read_text(), "(setq slime-default-lisp 'my-lispworks)\n")
        self.assertFalse((self.target/'early-init.el').exists())
        for name in ('custom.el', 'history', 'var/session', '.cache/gptel-openai/private', 'elpa-29.1/sample'):
            self.assertEqual((self.target/name).read_text(),'sentinel')
        self.assertTrue((self.target/'elpa-30.1/working').is_file())

    def test_compiled_managed_modules_block_install_and_update(self):
        modules = self.target/'lisp'
        modules.mkdir(parents=True)
        compiled = modules/'init-common-lisp.elc'
        compiled.write_bytes(b'old bytecode marker')
        other = modules/'unmanaged.elc'
        other.write_bytes(b'unrelated')
        for flags in [('--dry-run',), ('--adopt',), ('--config-only',)]:
            output = self.run_installer(*flags, ok=False)
            self.assertIn('lisp/init-common-lisp.elc', output)
            self.assertFalse((self.target/'init.el').exists())
            self.assertEqual(compiled.read_bytes(), b'old bytecode marker')
        compiled.unlink()
        self.run_installer()
        compiled.write_bytes(b'new bytecode marker')
        self.assertIn('lisp/init-common-lisp.elc', self.run_installer(ok=False))
        (self.payload/'init.el').write_text('changed release')
        self.assertIn('lisp/init-common-lisp.elc', self.run_installer('--adopt', ok=False))
        self.assertEqual((self.target/'init.el').read_text(), ';; portable\n')
        self.assertEqual(other.read_bytes(), b'unrelated')

    def test_bytecode_created_during_preflight_is_preserved(self):
        self.target.mkdir()
        compiled = self.target/'init.elc'
        self.exe('emacs', 'if [ "$1" = "--version" ]; then echo "GNU Emacs 30.1"; '
                 'else echo external > "$TEST_COMPILED_CONFIG"; fi')
        output = self.run_installer(ok=False, env=dict(self.env, TEST_COMPILED_CONFIG=str(compiled)))
        self.assertIn('init.elc', output)
        self.assertEqual(compiled.read_text(), 'external\n')
        self.assertFalse((self.target/'init.el').exists())
        self.assertFalse((self.target/'elpa-30.1').exists())

    def test_restore_preserves_changed_permissions_including_older_transactions(self):
        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                self.target = self.root/('legacy' if legacy else 'new')
                self.target.mkdir()
                init = self.target/'init.el'
                init.write_text('private previous version')
                init.chmod(0o600)
                self.run_installer('--adopt', '--config-only')
                early = self.target/'early-init.el'
                self.assertEqual(init.stat().st_mode & 0o777, 0o600)
                self.assertEqual(early.stat().st_mode & 0o777, 0o644)
                backup = self.backup()
                manifest = backup/'transaction.json'
                txn = json.loads(manifest.read_bytes())
                self.assertEqual(txn['files']['init.el']['after_mode'], 0o600)
                self.assertEqual(txn['files']['early-init.el']['after_mode'], 0o644)
                if legacy:
                    for row in txn['files'].values():
                        del row['after_mode']
                    manifest.write_text(json.dumps(txn))
                for file, original_mode, tightened in [(init, 0o600, 0o400), (early, 0o644, 0o600)]:
                    file.chmod(tightened)
                    for flags in [('--dry-run',), ()]:
                        out = self.run_installer('--restore', str(backup), *flags, ok=False)
                        self.assertIn(file.name, out)
                        self.assertEqual(file.stat().st_mode & 0o777, tightened)
                        self.assertEqual(init.read_text(), ';; portable\n')
                        self.assertTrue(early.is_file())
                    file.chmod(original_mode)
                self.run_installer('--restore', str(backup))
                self.assertEqual(init.read_text(), 'private previous version')
                self.assertEqual(init.stat().st_mode & 0o777, 0o600)
                self.assertFalse(early.exists())

    def test_concurrent_permission_change_rolls_back_partial_restore(self):
        self.target.mkdir()
        init = self.target/'init.el'
        init.write_text('old settings')
        init.chmod(0o644)
        installer = str(self.root/"release kit's installer.sh")
        output = self.run_installer('--config-only', '--adopt', env=dict(self.env, HAN_INSTALLER_FILE=installer))
        backup = self.backup()
        import shlex
        command = next(line for line in output.splitlines() if line.startswith('要恢复本次变更：'))
        self.assertEqual(shlex.split(command.split('：', 1)[1]),
                         ['bash', installer, '--target', str(self.target), '--restore', str(backup)])

        spec = importlib.util.spec_from_file_location('installer_fixture', self.repo/'bootstrap/configure.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        lock = module.locked

        @contextlib.contextmanager
        def change_after_planning(backup_root):
            with lock(backup_root):
                init.chmod(0o600)
                yield

        # The sorted manifest restores early-init.el first, then encounters a newer chmod on init.el.
        with patch.object(module, 'locked', change_after_planning):
            with self.assertRaisesRegex(module.InstallError, 'init.el'):
                module.restore(self.target, backup.parent, SimpleNamespace(restore=str(backup), dry_run=False))
        early = self.target/'early-init.el'
        self.assertEqual(early.read_text(), ';; early\n')
        self.assertEqual(early.stat().st_mode & 0o777, 0o644)
        self.assertEqual(init.read_text(), ';; portable\n')
        self.assertEqual(init.stat().st_mode & 0o777, 0o600)

    def test_manual_changes_rejected_and_non_destructive_restore(self):
        self.run_installer('--config-only')
        backup = self.backup()
        (self.target/'init.el').write_text('user')
        out = self.run_installer('--config-only', ok=False)
        self.assertIn('--adopt', out)
        self.run_installer('--restore', str(backup), ok=False)
        self.assertEqual((self.target/'init.el').read_text(), 'user')
        (self.payload/'early-init.el').write_text('version two')
        self.run_installer('--config-only','--adopt')
        b = [p for p in backup.parent.iterdir() if p.is_dir() and p != backup][0]
        self.run_installer('--restore',str(b))
        self.assertEqual((self.target/'init.el').read_text(),'user')
        self.assertEqual((self.target/'early-init.el').read_text(),';; early\n')

    def test_unavailable_backend_no_lisp_and_reselection(self):
        self.run_installer('--backend', 'missing', ok=False)
        self.assertFalse(self.target.exists())
        self.run_installer('--config-only', '--backend','my-lispworks')
        self.run_installer('--config-only')
        result = self.target/'var/slime-default-lisp'
        self.assertEqual(result.read_text(), 'my-lispworks\n')
        (self.bin/'my-lispworks').unlink()
        self.run_installer('--config-only')
        self.assertEqual(result.read_text(), 'sbcl\n')
        (self.bin/'sbcl').unlink()
        self.target = self.root/'empty'
        self.run_installer('--config-only')
        self.assertFalse((self.target/'var/slime-default-lisp').exists())

    def test_dependency_failures_do_not_touch_config(self):
        self.run_installer(ok=False,env=dict(self.env, FAKE_FAIL_PACKAGES='1'))
        self.assertFalse(self.target.exists())
        self.run_installer(ok=False,env=dict(self.env, FAKE_FAIL_STARTUP='1'))
        self.assertFalse(self.target.exists())
        (self.target/'elpa-30.1').mkdir(parents=True)
        self.run_installer(ok=False)
        self.assertFalse((self.target/'init.el').exists())
        self.run_installer('--config-only')
        self.assertTrue((self.target/'init.el').is_file())
        self.assertFalse((self.target/'elpa-30.1/working').exists())

    def test_guard_symlink_root_parent_and_leaf(self):
        sentinel = self.root/'protected'
        sentinel.mkdir()
        self.target.symlink_to(sentinel, target_is_directory=True)
        self.run_installer('--config-only', ok=False)
        self.target.unlink()
        self.target.mkdir()
        (self.target/'var').symlink_to(sentinel, target_is_directory=True)
        self.run_installer('--config-only',ok=False)
        self.assertEqual(list(sentinel.iterdir()),[])
        (self.target/'var').unlink()
        (self.target/'init.el').symlink_to(sentinel/'init.el')
        self.run_installer('--config-only','--adopt',ok=False)
        self.assertEqual(list(sentinel.iterdir()),[])

    def run_pty(self, answer, timeout):
        # forkpty 提供真正的控制终端，测试 /dev/tty，即使 stdin 在 shell 安装命令中被占用。
        pid, fd = pty.fork()
        if pid == 0:
            os.execve(str(self.repo/'install.sh'), [str(self.repo/'install.sh'), '--target',str(self.target),
                      '--config-only','--timeout',str(timeout)], self.env)
        out = b''
        seen = False
        try:
            deadline = time.monotonic()+8
            while time.monotonic()<deadline:
                avail = select.select([fd],[],[],0.1)[0]
                if avail:
                    try:
                        part = os.read(fd,65536)
                    except OSError:
                        break
                    if not part:
                        break
                    out += part
                    if not seen and '秒超时采用默认'.encode() in out:
                        seen = True
                        if answer is not None:
                            os.write(fd,answer.encode()+b'\n')
            else:
                os.kill(pid,9)
                self.fail('PTY test timeout')
        finally:
            os.close(fd)
            _, status = os.waitpid(pid,0)
        self.assertTrue(seen, out)
        self.assertEqual(status,0,out)

    def test_interactive_choice_and_real_timeout(self):
        self.run_pty('2',3)
        self.assertEqual((self.target/'var/slime-default-lisp').read_text(),'my-lispworks\n')
        self.target = self.root/'timeout'
        self.run_pty(None,1)
        self.assertEqual((self.target/'var/slime-default-lisp').read_text(),'sbcl\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
