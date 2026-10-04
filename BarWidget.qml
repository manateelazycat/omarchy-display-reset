import QtQuick
import QtQuick.Effects
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
    iconComponent: Component {
      Item {
        Image {
          id: iconImage
          anchors.fill: parent
          source: Qt.resolvedUrl("assets/display-reset.svg")
          sourceSize.width: 128
          sourceSize.height: 128
          fillMode: Image.PreserveAspectFit
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: parent
          source: iconImage
          colorization: 1
          colorizationColor: button.active && button.useActiveColor ? button.activeColor : button.foreground
          autoPaddingEnabled: false
        }
      }
    }
    active: root.resetService ? root.resetService.opened : false
    tooltipText: "重新加载显示器"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton && root.resetService)
        root.resetService.toggle()
    }
  }
}
