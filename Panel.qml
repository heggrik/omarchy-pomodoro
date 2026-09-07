import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.hennil.pomodoro-timer"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // The shared engine created once by the shell (kind "service"). Every
  // per-monitor panel routes through it so all screens show the same live
  // countdown and any press on any screen drives the same timer.
  property var service: null

  function resolveService() {
    if (root.service) return root.service
    var api = root.bar && root.bar.shell ? root.bar.shell : null
    if (!api) return null
    if (typeof api.serviceFor === "function") {
      root.service = api.serviceFor(root.moduleName)
      return root.service
    }
    if (typeof api.ensureService === "function") {
      root.service = api.ensureService(root.moduleName)
      return root.service
    }
    return null
  }

  onBarChanged: root.resolveService()
  Component.onCompleted: root.resolveService()

  // ---- config -----------------------------------------------------
  readonly property var presetMinutes: [5, 10, 15, 20, 25]
  property int defaultMinutes: 25
  property int shortBreakMinutes: 5
  property int longBreakMinutes: 15
  property int sessionsBeforeLongBreak: 4
  property bool autoStartNext: false

  // ---- state (mirrors the shared service; falls back while it resolves) --
  readonly property string phase: root.service ? root.service.phase : "focus"
  readonly property int totalSeconds: root.service ? root.service.totalSeconds : root.defaultMinutes * 60
  readonly property int remainingSeconds: root.service ? root.service.remainingSeconds : root.defaultMinutes * 60
  readonly property bool running: root.service ? root.service.running : false
  readonly property int focusSessionsDone: root.service ? root.service.focusSessionsDone : 0
  readonly property int todayFocusCount: root.service ? root.service.todayFocusCount : 0
  readonly property bool soundEnabled: root.service ? root.service.soundEnabled : true
  readonly property int selectedPreset: root.service ? root.service.selectedPreset : root.defaultMinutes

  readonly property real progressFraction: root.service
    ? root.service.progressFraction : 0

  readonly property string phaseLabel: root.service
    ? root.service.phaseLabel : "Focus"

  readonly property string barLabel: root.service
    ? root.service.barLabel : "25:00"

  // ---- public actions (forward to the shared engine) ---------------
  function open() { root.controller.show() }
  function close() { root.controller.hide() }

  function startPause() { if (root.service) root.service.startPause() }
  function skip() { if (root.service) root.service.skip() }
  function reset() { if (root.service) root.service.reset() }
  function setPhaseLength(minutes) { if (root.service) root.service.setPhaseLength(minutes) }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  // ---- UI ---------------------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(14)

        // -- ring -----------------------------------------------------
        Item {
          width: parent.width
          height: 200

          Canvas {
            id: ring
            anchors.centerIn: parent
            width: 200
            height: 200

            property real fraction: root.progressFraction
            property string centerText: {
              var m = Math.floor(Math.max(0, root.remainingSeconds) / 60)
              var s = Math.max(0, root.remainingSeconds) % 60
              return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
            }
            property string phaseText: root.phaseLabel

            onFractionChanged: requestPaint()
            onCenterTextChanged: requestPaint()
            onPhaseTextChanged: requestPaint()

            onPaint: {
              var ctx = getContext("2d")
              ctx.reset()
              var cx = width / 2, cy = height / 2
              var r = Math.min(cx, cy) - 14

              ctx.lineWidth = 10
              ctx.lineCap = "round"

              ctx.strokeStyle = Qt.darker(root.barForeground || "#f0f0f0", 1.8)
              ctx.beginPath()
              ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
              ctx.stroke()

              ctx.strokeStyle = (typeof Color !== "undefined" && Color.accent) ? Color.accent : "#7f77dd"
              ctx.beginPath()
              var start = -Math.PI / 2
              var end = start + Math.PI * 2 * fraction
              ctx.arc(cx, cy, r, start, end, false)
              ctx.stroke()

              ctx.fillStyle = root.barForeground || "#f0f0f0"
              ctx.textAlign = "center"
              ctx.font = "30px " + (root.bar ? root.bar.fontFamily : Style.font.family)
              ctx.fillText(centerText, cx, cy + 6)

              ctx.font = "12px " + (root.bar ? root.bar.fontFamily : Style.font.family)
              ctx.globalAlpha = 0.7
              ctx.fillText(phaseText, cx, cy + 28)
              ctx.globalAlpha = 1.0
            }
          }
        }

        // -- presets ----------------------------------------------------
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Repeater {
            model: root.presetMinutes
            delegate: Rectangle {
              property int minutes: modelData
              width: 44
              height: 28
              radius: 999
              color: root.selectedPreset === minutes && root.phase === "focus"
                ? ((typeof Color !== "undefined" && Color.accent) ? Color.accent : "#7f77dd")
                : "transparent"
              border.width: 1
              border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)

              Text {
                anchors.centerIn: parent
                text: minutes + "m"
                font.pixelSize: 13
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                color: root.selectedPreset === minutes && root.phase === "focus"
                  ? "#101014" : root.barForeground
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (!root.service) return
                  root.service.pauseTimer()
                  root.service.setPhaseLength(minutes)
                }
              }
            }
          }
        }

        // -- custom minutes ------------------------------------------
        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            Layout.fillWidth: true
            height: 30
            radius: 6
            color: "transparent"
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)

            TextInput {
              id: customInput
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: root.barForeground
              font.pixelSize: 13
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              validator: IntValidator { bottom: 1; top: 180 }
              selectByMouse: true

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Custom minutes"
                color: Qt.darker(root.barForeground || "#f0f0f0", 1.4)
                font.pixelSize: 13
                visible: customInput.text.length === 0
              }
            }
          }

          Rectangle {
            width: 52
            height: 30
            radius: 6
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: "Set"
              color: root.barForeground
              font.pixelSize: 13
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                var minutes = parseInt(customInput.text, 10)
                if (!minutes || minutes < 1) return
                if (!root.service) return
                root.service.pauseTimer()
                root.service.setPhaseLength(minutes)
                customInput.text = ""
              }
            }
          }
        }

        // -- transport ----------------------------------------------
        RowLayout {
          width: parent.width
          spacing: Style.space(6)

          Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: root.running ? "Pause" : "Start"
              color: root.barForeground
              font.pixelSize: 13
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
            }

            MouseArea { anchors.fill: parent; onClicked: root.startPause() }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: "Reset"
              color: root.barForeground
              font.pixelSize: 13
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
            }

            MouseArea { anchors.fill: parent; onClicked: root.reset() }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 6
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: "Skip"
              color: root.barForeground
              font.pixelSize: 13
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
            }

            MouseArea { anchors.fill: parent; onClicked: root.skip() }
          }
        }

        // -- footer ----------------------------------------------------
        RowLayout {
          width: parent.width

          Text {
            Layout.fillWidth: true
            text: (root.focusSessionsDone % root.sessionsBeforeLongBreak) + "/" +
                  root.sessionsBeforeLongBreak + " cycle \u00b7 " +
                  root.todayFocusCount + " today"
            color: Qt.darker(root.barForeground || "#f0f0f0", 1.3)
            font.pixelSize: 12
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Rectangle {
            width: 78
            height: 24
            radius: 999
            border.width: 1
            border.color: Qt.darker(root.barForeground || "#f0f0f0", 1.6)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: root.soundEnabled ? "Sound on" : "Sound off"
              color: root.barForeground
              font.pixelSize: 11
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (root.service)
                  root.service.soundEnabled = !root.service.soundEnabled
              }
            }
          }
        }
      }
    }
  }
}