pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar: null
  property var tokens: null
  property int movieCount: 0
  property bool active: false
  property string tooltipText: ""
  property real labelWidth: label.implicitWidth + 24

  signal pressed(var button)

  implicitWidth: label.implicitWidth + 24
  implicitHeight: bar && bar.barSize ? bar.barSize : Style.bar.iconSlot

  Rectangle {
    anchors.fill: parent
    anchors.margins: 2
    radius: 4
    color: root.active ? Color.accent + "33" : "transparent"

    Row {
      anchors.centerIn: parent
      spacing: 4

      Text {
        text: "\uD83C\uDFAC"
        font.family: Style.font.family
        font.pixelSize: tokens ? tokens.iconSize : Style.space(15)
        color: Color.foreground
      }

      Text {
        id: label
        text: root.movieCount > 0
          ? root.movieCount + " playing"
          : "Movies"
        font.family: Style.font.family
        font.pixelSize: tokens ? tokens.labelSize : Style.font.body
        color: Color.foreground
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      root.pressed(mouse.button)
    }
    onEntered: tooltipLoader.active = true
    onExited: tooltipLoader.active = false
  }

  Loader {
    id: tooltipLoader
    active: false
    sourceComponent: Tooltip {}
  }

  component Tooltip: Rectangle {
    width: tooltipText.implicitWidth + 16
    height: 24
    radius: 4
    color: Color.background
    border.color: Color.muted
    border.width: 1
    y: -30
    anchors.horizontalCenter: parent.horizontalCenter
    visible: true

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: root.tooltipText
      font.family: Style.font.family
      font.pixelSize: 10
      color: Color.foreground
    }
  }
}
