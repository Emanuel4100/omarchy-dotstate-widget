import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "emanuel.dotstate"
  ipcTarget: "emanuel.dotstate"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property color stateColor: {
    if (dotstate.displayState === "error") return urgent
    if (dotstate.displayState === "dirty") return Color.accent
    return foreground
  }
  readonly property color barStateColor: {
    if (dotstate.displayState === "error") return bar ? bar.urgent : Color.urgent
    if (dotstate.displayState === "dirty") return Color.accent
    return barForeground
  }
  readonly property real iconOpacity: dotstate.displayState === "syncing" ? 0.55 : 1.0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) dotstate.refresh()

  Service {
    id: dotstate
    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { dotstate.refresh(); return "ok" }
    function sync(): string { dotstate.sync(); return "ok" }
    function status(): string { return dotstate.displayState }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Dotstate: " + Model.stateLabel(dotstate.displayState, dotstate.dirtyFiles.length)
    iconComponent: Component {
      Item {
        DotstateIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barStateColor
          opacity: root.iconOpacity

          RotationAnimation on rotation {
            running: dotstate.displayState === "syncing"
            from: 0; to: 360
            duration: 1200
            loops: Animation.Infinite
          }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) dotstate.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") dotstate.refresh()
        else if (t === "s" || t === "S") dotstate.sync()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Dotstate"
            meta: Model.stateLabel(dotstate.displayState, dotstate.dirtyFiles.length)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.iconOpacity
            iconComponent: Component {
              DotstateIcon {
                iconSize: Style.font.display
                color: root.stateColor
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: ""
                tooltipText: "Sync now"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !dotstate.busy
                onClicked: dotstate.sync()
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: dotstate.actionStatus !== ""
            width: parent.width
            text: dotstate.actionStatus
            color: dotstate.displayState === "error" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.spacing.labelGap

            InfoPair { label: "Profile"; value: dotstate.activeProfile !== "" ? dotstate.activeProfile : "Unknown" }
            InfoPair { label: "Remote"; value: Model.aheadBehindText(dotstate.ahead, dotstate.behind) }
            InfoPair {
              label: "Last remote update"
              value: dotstate.lastRemoteCommitTs !== "" ? Model.relativeTime(dotstate.lastRemoteCommitTs) : "Unknown"
            }
            Text {
              textFormat: Text.PlainText
              visible: dotstate.lastRemoteCommitMsg !== ""
              width: parent.width
              text: dotstate.lastRemoteCommitMsg
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: dotstate.lastError !== ""
            width: parent.width
            text: dotstate.lastError
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Column {
            visible: dotstate.dirtyFiles.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader {
              text: "LOCAL CHANGES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: dotstate.dirtyFiles
              RowLayout {
                required property var modelData
                width: parent.width
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  text: Model.fileStatusGlyph(modelData)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  Layout.alignment: Qt.AlignVCenter
                }
                Text {
                  textFormat: Text.PlainText
                  Layout.fillWidth: true
                  text: modelData.path
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }
              }
            }
          }

          Column {
            visible: dotstate.doctorIssues.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader {
              text: "DOCTOR"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: dotstate.doctorIssues
              Column {
                required property var modelData
                width: parent.width
                spacing: Style.space(1)

                readonly property string fixHint: Model.doctorFixHint(modelData)

                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: "• " + modelData.message
                  color: modelData.status === "Error" ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }
                Text {
                  textFormat: Text.PlainText
                  visible: fixHint !== ""
                  width: parent.width
                  text: fixHint
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                  leftPadding: Style.space(12)
                }
              }
            }
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.foreground
    opacity: 0.6
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    elide: Text.ElideRight
  }
}
