# Display Reset

简体中文 | [English](README.md)

![Display Reset 四屏预览](preview.png)

Omarchy Shell 插件。任务栏右侧图标打开时，会在所有显示器显示相同的选择对话框。对话框根据 `hyprctl monitors -j` 的当前坐标和旋转排列显示器；在任一屏幕上勾选后，选择会同步到所有对话框。

点击 **Reload** 后，插件停止 `hyprmoncfgd.service`，备份 `~/.config/hypr/hyprmoncfg-monitors.lua`，仅为所选输出临时写入 `disabled = true`，执行 `hyprctl reload`，等待两秒，恢复原配置并再次加载，最后启动服务并检查 `hyprctl configerrors`。执行失败时也会尝试恢复配置和服务。如果检测到其他进程在此期间修改了显示器配置，插件会保留该修改、报告冲突，并将原配置备份留在运行时目录。

## 运行要求

需要 Omarchy Shell 和 Hyprland。重启显示器还需要 Python 3、`hyprctl`、`systemctl --user`、运行中的 `hyprmoncfgd.service`，以及生成的 `~/.config/hypr/hyprmoncfg-monitors.lua` 文件。本地安装脚本还使用 Python 3 和 `jq`。

## 安装

通过 Omarchy 插件管理器安装：

```bash
omarchy plugin add https://github.com/manateelazycat/omarchy-display-reset.git --enable --yes
```

或者在本地项目目录运行：

```bash
./install.sh
```

安装脚本将项目目录链接到 `~/.config/omarchy/plugins/andy.display-reset`，并将图标放在任务栏右侧。修改弹窗代码后，运行 `omarchy restart shell` 加载新版界面。

也可以运行 `omarchy-shell andy.display-reset show` 打开对话框。

## 卸载

```bash
omarchy plugin remove andy.display-reset --yes
```

如果是本地安装，这个命令只会移除项目链接，不会删除项目目录。

## 协议

本项目采用 GNU General Public License version 3.0 only（`GPL-3.0-only`），详见 [LICENSE](LICENSE)。
