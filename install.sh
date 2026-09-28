#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/andy.display-reset"

if [[ -e "$plugin_dir" && ! -L "$plugin_dir" ]]; then
  echo "插件目录已存在，无法建立项目链接：$plugin_dir" >&2
  exit 1
fi
if [[ -L "$plugin_dir" && "$(readlink -f -- "$plugin_dir")" != "$project_dir" ]]; then
  echo "插件目录已经指向其他位置：$plugin_dir" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$plugin_dir")"
ln -sfn -- "$project_dir" "$plugin_dir"
omarchy plugin validate "$project_dir"
export OMARCHY_SHELL_IPC_TIMEOUT=20s
omarchy-shell shell rescanPlugins
discovered=false
for ((attempt = 0; attempt < 20; attempt++)); do
  if omarchy plugin list --json 2>/dev/null | jq -e 'any(.[]; .id == "andy.display-reset")' >/dev/null; then
    discovered=true
    break
  fi
  sleep 1
done
if [[ "$discovered" != true ]]; then
  echo "Omarchy Shell 未能发现插件，请检查 shell 运行状态" >&2
  exit 1
fi
shell_config="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
if [[ -f "$shell_config" ]]; then
  python3 - "$shell_config" <<'PY'
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

source_path = Path(sys.argv[1])
with source_path.open("rb") as source:
    source_stat = os.fstat(source.fileno())
    descriptor, backup_name = tempfile.mkstemp(
        prefix=f"{source_path.name}.bak.display-reset.", dir=source_path.parent
    )
    try:
        with os.fdopen(descriptor, "wb") as backup:
            shutil.copyfileobj(source, backup)
            backup.flush()
            os.fchmod(backup.fileno(), stat.S_IMODE(source_stat.st_mode))
            os.utime(backup.fileno(), ns=(source_stat.st_atime_ns, source_stat.st_mtime_ns))
            os.fsync(backup.fileno())
    except BaseException:
        os.unlink(backup_name)
        raise
PY
fi
omarchy plugin enable andy.display-reset
omarchy bar move andy.display-reset --section right
echo "Display Reset 已安装到任务栏右侧。"
