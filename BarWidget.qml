import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "andy.display-reset"

  readonly property var resetService: bar?.shell?.serviceFor(root.moduleName)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰑓"
    active: root.resetService ? root.resetService.opened : false
    tooltipText: "重新加载显示器"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton && root.resetService)
        root.resetService.toggle()
    }
  }
}
