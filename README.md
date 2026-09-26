# Display Reset

English | [简体中文](README.zh-CN.md)

![Display Reset on four monitors](preview.png)

This Omarchy Shell plugin adds an icon to the right side of the bar. Clicking it opens the same dialog on every monitor. The dialog arranges monitors using their current coordinates and rotation from `hyprctl monitors -j`. Selecting a monitor in any dialog updates the selection in all of them.

After you click **Reload**, the plugin stops `hyprmoncfgd.service`, backs up `~/.config/hypr/hyprmoncfg-monitors.lua`, and temporarily adds `disabled = true` only to the selected outputs. It runs `hyprctl reload`, waits two seconds, restores the original configuration, reloads again, starts the service, and checks `hyprctl configerrors`. It also attempts to restore the configuration and service if an operation fails.

## Install

```bash
./install.sh
```

The installer links this project to `~/.config/omarchy/plugins/andy.display-reset` and places its icon on the right side of the bar. After changing the dialog code, run `omarchy restart shell` to load the new version.

You can also open the dialog with `omarchy-shell andy.display-reset show`.

## License

This project is licensed under the GNU General Public License version 3.0 only (`GPL-3.0-only`). See [LICENSE](LICENSE).
