import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.hennil.pomodoro-timer"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Exposed so Hyprland binds / `omarchy-shell shell call <id> <method> ""`
  // can drive the timer without opening the panel.
  function startPause() {
    if (panelLoader.item) panelLoader.item.startPause()
  }

  function skip() {
    if (panelLoader.item) panelLoader.item.skip()
  }

  function reset() {
    if (panelLoader.item) panelLoader.item.reset()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = label
    panelLoader.item.hostWidget = root
  }

  implicitWidth: label.implicitWidth + 16
  implicitHeight: 28

  onBarChanged: injectPanel()

  // active: true means the timer keeps running/ticking in the background
  // even while the panel itself is closed - that's what lets the bar
  // label show a live countdown at all times.
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: panelLoader.item ? panelLoader.item.barLabel : "25:00"
    font.pixelSize: 13
    font.family: root.bar ? root.bar.fontFamily : "sans-serif"
    color: root.bar ? root.bar.foreground : "#f0f0f0"
  }

  MouseArea {
    id: clickArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.toggle()
      else if (mouse.button === Qt.RightButton) root.startPause()
    }
  }
}
