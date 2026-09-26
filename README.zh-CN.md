# Display Reset

简体中文 | [English](README.md)

![Display Reset 四屏预览](preview.png)

Omarchy Shell 插件。任务栏右侧图标打开时，会在所有显示器显示相同的选择对话框。对话框根据 `hyprctl monitors -j` 的当前坐标和旋转排列显示器；在任一屏幕上勾选后，选择会同步到所有对话框。

点击 **Reload** 后，插件停止 `hyprmoncfgd.service`，备份 `~/.config/hypr/hyprmoncfg-monitors.lua`，仅为所选输出临时写入 `disabled = true`，执行 `hyprctl reload`，等待两秒，恢复原配置并再次加载，最后启动服务并检查 `hyprctl configerrors`。执行失败时也会尝试恢复配置和服务。

安装：

```bash
./install.sh
```

安装脚本将项目目录链接到 `~/.config/omarchy/plugins/andy.display-reset`，并将图标放在任务栏右侧。修改弹窗代码后，运行 `omarchy restart shell` 加载新版界面。

也可以运行 `omarchy-shell andy.display-reset show` 打开对话框。

## 协议

本项目采用 GNU General Public License version 3.0 only（`GPL-3.0-only`），详见 [LICENSE](LICENSE)。
