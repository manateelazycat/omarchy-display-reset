import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Layout.js" as DisplayLayout

Item {
  id: root

  property bool opened: false
  property bool busy: false
  property var displays: []
  property var selected: []
  property string statusMessage: ""
  property bool statusError: false
  readonly property var layoutBounds: DisplayLayout.bounds(displays)
  readonly property string helperPath: {
    var url = String(Qt.resolvedUrl("reload_displays.py"))
    try { return decodeURIComponent(url.replace(/^file:\/\//, "")) }
    catch (error) { return url.replace(/^file:\/\//, "") }
  }

  function open() {
    if (root.opened) return
    root.selected = []
    root.statusMessage = ""
    root.opened = true
    root.refresh()
  }

  function close() {
    if (!root.busy) root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function refresh() {
    if (!root.busy && !monitorProcess.running) monitorProcess.running = true
  }

  function toggleSelection(name) {
    if (root.busy) return
    var next = root.selected.slice()
    var index = next.indexOf(name)
    if (index < 0) next.push(name)
    else next.splice(index, 1)
    root.selected = next
    root.statusMessage = ""
  }

  function reload() {
    if (root.busy || root.selected.length === 0) return
    root.busy = true
    root.statusError = false
    root.statusMessage = "正在重新加载所选显示器…"
    reloadProcess.command = ["/usr/bin/python3", root.helperPath].concat(root.selected)
    reloadProcess.running = true
  }

  Process {
    id: monitorProcess
    command: ["hyprctl", "monitors", "-j"]
    stdout: StdioCollector { id: monitorOutput; waitForEnd: true }
    stderr: StdioCollector { id: monitorError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root.opened && !root.busy) {
          root.statusError = true
          root.statusMessage = String(monitorError.text || "无法读取显示器信息").trim()
        }
        return
      }
      try {
        var parsed = JSON.parse(String(monitorOutput.text || "[]"))
        root.displays = DisplayLayout.normalize(parsed, Quickshell.screens)
        var names = root.displays.map(function(display) { return display.name })
        root.selected = root.selected.filter(function(name) { return names.indexOf(name) >= 0 })
      } catch (error) {
        root.statusError = true
        root.statusMessage = "显示器信息格式错误：" + error
      }
    }
  }

  Process {
    id: reloadProcess
    stdout: StdioCollector { id: reloadOutput; waitForEnd: true }
    stderr: StdioCollector { id: reloadError; waitForEnd: true }
    onExited: function(exitCode) {
      root.busy = false
      try {
        var result = JSON.parse(String(reloadOutput.text || "{}"))
        root.statusError = exitCode !== 0 || !result.ok
        root.statusMessage = String(result.message || result.error || "操作没有返回结果")
        if (!root.statusError) root.selected = []
      } catch (error) {
        root.statusError = true
        root.statusMessage = String(reloadError.text || "显示器重载失败").trim()
      }
      root.refresh()
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() { if (root.opened) root.refresh() }
  }

  IpcHandler {
    target: "andy.display-reset"
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property ShellScreen modelData
      screen: modelData
      visible: root.opened
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "andy-display-reset"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
      anchors { top: true; bottom: true; left: true; right: true }

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.66)
        MouseArea {
          anchors.fill: parent
          onClicked: root.close()
        }
      }

      Item {
        anchors.fill: parent
        focus: root.opened
        Keys.onEscapePressed: root.close()

        Rectangle {
          id: card
          width: 680
          height: 516
          anchors.centerIn: parent
          scale: Math.min(1, (parent.width - 28) / width, (parent.height - 28) / height)
          radius: 0
          color: Color.background
          border.color: Color.accent
          border.width: 1

          MouseArea { anchors.fill: parent; onClicked: {} }

          Text {
            x: 28; y: 24
            text: "重新加载显示器"
            textFormat: Text.PlainText
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: 23
            font.bold: true
          }

          Text {
            x: 28; y: 60
            width: 624
            text: "多显示时遇到显示器意外镜像时，可通过重启显示器来恢复信号"
            textFormat: Text.PlainText
            color: Color.foreground
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: 14
          }

          Rectangle {
            id: canvas
            x: 28; y: 100; width: 624; height: 314
            radius: 0
            color: Qt.rgba(0.5, 0.5, 0.5, 0.09)
            border.color: Qt.rgba(0.5, 0.5, 0.5, 0.25)

            Text {
              anchors.centerIn: parent
              visible: root.displays.length === 0
              text: "正在读取显示器…"
              color: Color.foreground
              opacity: 0.65
              font.family: Style.font.family
              font.pixelSize: 15
            }

            Repeater {
              model: root.displays
              delegate: Rectangle {
                required property var modelData
                readonly property var geometry: DisplayLayout.rect(modelData, root.layoutBounds,
                                                                   canvas.width, canvas.height, 18)
                readonly property bool checked: root.selected.indexOf(modelData.name) >= 0
                x: geometry.x
                y: geometry.y
                width: geometry.width
                height: geometry.height
                radius: 0
                color: checked ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3)
                               : Qt.rgba(0.5, 0.5, 0.5, 0.15)
                border.color: checked ? Color.accent : Color.foreground
                border.width: checked ? 2 : 1

                Text {
                  anchors.centerIn: parent
                  width: Math.max(1, parent.width - 16)
                  text: modelData.name + "\n" + modelData.model
                  textFormat: Text.PlainText
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.Wrap
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: 14
                  font.bold: true
                }

                Rectangle {
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 8
                  width: 20; height: 20
                  radius: 0
                  color: checked ? Color.accent : "transparent"
                  border.color: checked ? Color.accent : Color.foreground
                  Text {
                    anchors.centerIn: parent
                    visible: checked
                    text: "✓"
                    color: Color.background
                    font.pixelSize: 15
                    font.bold: true
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleSelection(modelData.name)
                }
              }
            }
          }

          Text {
            x: 28; y: 430
            width: 470
            height: 48
            visible: root.statusMessage !== ""
            text: root.statusMessage
            textFormat: Text.PlainText
            color: root.statusError ? Color.urgent : Color.foreground
            font.family: Style.font.family
            font.pixelSize: 14
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
          }

          Rectangle {
            x: 562; y: 440; width: 90; height: 36
            radius: 0
            color: root.selected.length > 0 && !root.busy ? Color.accent : Qt.rgba(0.5, 0.5, 0.5, 0.2)
            Text {
              anchors.centerIn: parent
              text: root.busy ? "处理中…" : "Reload"
              color: root.selected.length > 0 && !root.busy ? Color.background : Color.foreground
              font.family: Style.font.family
              font.pixelSize: 14
              font.bold: true
            }
            MouseArea {
              anchors.fill: parent
              enabled: root.selected.length > 0 && !root.busy
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.reload()
            }
          }
        }
      }
    }
  }
}
