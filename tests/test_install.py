import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "install.sh"


class InstallTests(unittest.TestCase):
    def test_backups_are_unique_and_do_not_follow_existing_symlinks(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            config_home = base / "config"
            shell_config = config_home / "omarchy" / "shell.json"
            shell_config.parent.mkdir(parents=True)
            shell_config.write_text('{"bar": []}\n', encoding="utf-8")
            shell_config.chmod(0o640)
            os.utime(shell_config, ns=(1_600_000_000_000_000_000,) * 2)

            existing = base / "existing-config"
            existing.write_text("preserve this file", encoding="utf-8")
            old_backup_name = shell_config.with_name("shell.json.bak.display-reset.20260928111111")
            old_backup_name.symlink_to(existing)

            bin_dir = base / "bin"
            bin_dir.mkdir()
            commands = {
                "omarchy": '#!/bin/sh\nif [ "$1" = plugin ] && [ "$2" = list ]; then echo \'[{"id":"andy.display-reset"}]\'; fi\n',
                "omarchy-shell": "#!/bin/sh\nexit 0\n",
                "jq": "#!/bin/sh\nexit 0\n",
                "date": "#!/bin/sh\necho 20260928111111\n",
            }
            for name, body in commands.items():
                executable = bin_dir / name
                executable.write_text(body, encoding="utf-8")
                executable.chmod(0o755)

            environment = dict(os.environ, XDG_CONFIG_HOME=str(config_home))
            environment["PATH"] = f"{bin_dir}:{os.environ['PATH']}"
            for _ in range(2):
                completed = subprocess.run(
                    ["bash", str(INSTALLER)], env=environment, capture_output=True, text=True
                )
                self.assertEqual(completed.returncode, 0, completed.stderr)

            self.assertEqual(existing.read_text(encoding="utf-8"), "preserve this file")
            self.assertTrue(old_backup_name.is_symlink())
            backups = [
                path for path in shell_config.parent.glob("shell.json.bak.display-reset.*")
                if path != old_backup_name
            ]
            self.assertEqual(len(backups), 2)
            for backup in backups:
                self.assertTrue(backup.is_file())
                self.assertFalse(backup.is_symlink())
                self.assertEqual(backup.read_bytes(), shell_config.read_bytes())
                self.assertEqual(stat.S_IMODE(backup.stat().st_mode), 0o640)
                self.assertEqual(backup.stat().st_mtime_ns, shell_config.stat().st_mtime_ns)


if __name__ == "__main__":
    unittest.main()
