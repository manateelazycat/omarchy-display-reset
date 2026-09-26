#!/usr/bin/env python3
"""Temporarily disable selected hyprmoncfg outputs, then restore the config."""

import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time


OUTPUT_NAME = re.compile(r"^[A-Za-z0-9_-]+$")
MONITOR_BLOCK = re.compile(r"(?ms)^hl\.monitor\(\{\s*\n(?P<body>.*?)^\}\)\s*$")
OUTPUT_LINE = re.compile(r'(?m)^(?P<indent>\s*)output\s*=\s*"(?P<name>[^"\n]+)"\s*,\s*$')
DISABLED_LINE = re.compile(r"(?m)^\s*disabled\s*=")


def temporary_configuration(original: str, selected: set[str]) -> str:
    """Change only the selected monitor blocks in a generated Lua file."""
    found: set[str] = set()

    def edit(match: re.Match[str]) -> str:
        body = match.group("body")
        outputs = list(OUTPUT_LINE.finditer(body))
        if len(outputs) != 1 or outputs[0].group("name") not in selected:
            return match.group(0)
        name = outputs[0].group("name")
        if name in found:
            raise ValueError(f"配置中重复的输出：{name}")
        if DISABLED_LINE.search(body):
            raise ValueError(f"输出 {name} 已有 disabled 配置")
        found.add(name)
        output_line = outputs[0]
        position = output_line.end()
        updated = body[:position] + "\n" + output_line.group("indent") + "disabled = true," + body[position:]
        return match.group(0).replace(body, updated, 1)

    changed = MONITOR_BLOCK.sub(edit, original)
    missing = selected - found
    if missing:
        raise ValueError("配置中找不到输出：" + ", ".join(sorted(missing)))
    return changed


def command(*args: str) -> str:
    completed = subprocess.run(args, text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise RuntimeError(f"{' '.join(args)} 失败：{detail or completed.returncode}")
    return completed.stdout.strip()


def write_atomically(path: Path, contents: bytes, source: Path) -> None:
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        shutil.copystat(source, temporary)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def interrupted(_signum: int, _frame: object) -> None:
    raise InterruptedError("操作被中断")


def reload_displays(selected: set[str]) -> str:
    if not selected or any(not OUTPUT_NAME.fullmatch(name) for name in selected):
        raise ValueError("请选择有效的显示器输出")

    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    config = config_home / "hypr" / "hyprmoncfg-monitors.lua"
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if not config.is_file() or config.is_symlink():
        raise FileNotFoundError(f"找不到常规配置文件：{config}")
    if not runtime.is_dir():
        raise FileNotFoundError(f"找不到运行时目录：{runtime}")

    connected = {str(item.get("name", "")) for item in json.loads(command("hyprctl", "monitors", "-j"))
                 if not item.get("disabled", False)}
    absent = selected - connected
    if absent:
        raise ValueError("显示器已断开：" + ", ".join(sorted(absent)))

    lock_path = runtime / "andy-display-reset.lock"
    with lock_path.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        command("systemctl", "--user", "stop", "hyprmoncfgd.service")
        backup_path: Path | None = None
        changed = False
        failures: list[str] = []
        try:
            original = config.read_text(encoding="utf-8")
            temporary = temporary_configuration(original, selected)
            descriptor, backup_name = tempfile.mkstemp(
                prefix="hyprmoncfg-monitors.pre-modeset.", suffix=".lua", dir=runtime
            )
            os.close(descriptor)
            backup_path = Path(backup_name)
            shutil.copy2(config, backup_path)
            write_atomically(config, temporary.encode("utf-8"), backup_path)
            changed = True
            command("hyprctl", "reload")
            time.sleep(2)
        except Exception as error:
            failures.append(str(error))
        finally:
            if changed and backup_path is not None:
                try:
                    write_atomically(config, backup_path.read_bytes(), backup_path)
                    command("hyprctl", "reload")
                except Exception as error:
                    failures.append("恢复配置失败：" + str(error))
            try:
                command("systemctl", "--user", "start", "hyprmoncfgd.service")
            except Exception as error:
                failures.append("启动 hyprmoncfgd 失败：" + str(error))
            if backup_path is not None:
                if failures and any(message.startswith("恢复配置失败") for message in failures):
                    failures.append(f"原配置备份保留在 {backup_path}")
                else:
                    backup_path.unlink(missing_ok=True)

        if failures:
            raise RuntimeError("；".join(failures))
        errors = command("hyprctl", "configerrors")
        if errors:
            raise RuntimeError("Hyprland 配置错误：" + errors)
        return "已重新加载：" + "、".join(sorted(selected))


def main() -> int:
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        message = reload_displays(set(sys.argv[1:]))
        print(json.dumps({"ok": True, "message": message}, ensure_ascii=False), flush=True)
        return 0
    except (Exception, KeyboardInterrupt) as error:
        print(json.dumps({"ok": False, "error": str(error)}, ensure_ascii=False), flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
