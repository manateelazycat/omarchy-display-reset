"""Check live dialog theme bindings without reloading displays or changing locales."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="omarchy-plugin-theme-") as directory:
        root = Path(directory)
        plugin = root / "Plugin"
        plugin.mkdir()
        for path in (*source.glob("*.qml"), *source.glob("*.js")):
            shutil.copy2(path, plugin / path.name)
        service = plugin / "Service.qml"
        text = service.read_text()
        text = re.sub(r'^import .* as SidePanelUi.*\n', '', text, flags=re.M)
        text = re.sub(r'^.*SidePanelUi.PopupStyler.*\n', '', text, flags=re.M)
        # Instantiate the real dialogs while preventing compositor input or painting.
        text = text.replace('visible: root.opened\n      color:', 'visible: false\n      color:')
        text = text.replace('visible: (root.opened || root.noticeVisible) && modelData.name === root.targetScreenName', 'visible: false')
        text = text.replace('id: root\n', 'id: root\n  property alias themeTestPanels: themeTestPanels\n', 1)
        text = text.replace('  Variants {', '  Variants {\n    id: themeTestPanels', 1)
        service.write_text(text)
        if (source / "CompatUi").exists():
            shutil.copytree(source / "CompatUi", plugin / "CompatUi")
        for name in ("Commons", "Ui"):
            (root / name).symlink_to(Path('/usr/share/omarchy/shell') / name, target_is_directory=True)
        shutil.copy2(source / "tests/theme.qml", root / "shell.qml")
        env = {**os.environ, "QT_QPA_PLATFORM": "wayland", "QT_QUICK_BACKEND": "software",
               "XDG_CONFIG_HOME": str(root / "config"), "QS_DISABLE_FILE_WATCHER": "1"}
        result = subprocess.run(["quickshell", "-p", str(root), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=15)
        output = result.stdout + result.stderr
        if result.returncode or "PLUGIN_THEME_PASS" not in output or re.search(
                r"PLUGIN_THEME_FAIL|TypeError|ReferenceError|Unable to assign|ERROR:|Cannot read property", output):
            raise SystemExit(output)
        print("PASS: actual dialog colors follow dark/light theme changes")


if __name__ == '__main__':
    main()
