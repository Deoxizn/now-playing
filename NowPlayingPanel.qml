pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "com.user.now-playing"
  ipcTarget: ""
  manageIpc: false

  readonly property string serviceId: "com.user.now-playing"
  readonly property var service: bar && bar.shell
    && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(serviceId) : null
  readonly property var movies: service ? service.movies : []
  readonly property var theaters: service ? service.theaters : []
  readonly property bool loading: service ? service.loading : false
  readonly property bool searchingTheaters: service ? service.searchingTheaters : false
  readonly property string theaterName: service ? service.theaterName : ""

  HostTokens {
    id: hostTokens
    bar: root.bar
  }

  readonly property var tokens: bar && "visualTokens" in bar && bar.visualTokens
    ? bar.visualTokens : hostTokens

  property bool serviceClaimed: false
  property int serviceTries: 0

  function tryClaimService() {
    if (root.service && !root.serviceClaimed) {
      root.serviceClaimed = true
      root.serviceTries = 0
      serviceRetry.stop()
    } else if (!root.service && root.serviceTries < 30) {
      root.serviceTries++
      serviceRetry.restart()
    }
  }

  onServiceChanged: tryClaimService()
  Component.onCompleted: tryClaimService()
  Component.onDestruction: serviceRetry.stop()

  Timer {
    id: serviceRetry
    interval: 500
    onTriggered: root.tryClaimService()
  }

  readonly property bool pillActive: root.loading
  readonly property string tooltipText: {
    if (root.movies.length > 0)
      return root.movies.length + " movie" + (root.movies.length === 1 ? "" : "s") + " at " + root.theaterName
    return "Now Playing"
  }

  readonly property real openPanelIndicatorWidth: Math.max(
    Style.space(10), pill.labelWidth)
  readonly property real openPanelIndicatorHeight: Math.max(
    Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  property string searchText: ""
  property bool showTheaterSearch: false

  function getFilteredMovies() {
    if (!root.movies) return []
    if (root.searchText.length === 0) return root.movies
    var filtered = []
    for (var i = 0; i < root.movies.length; i++) {
      var m = root.movies[i]
      if (m.title && m.title.toLowerCase().indexOf(root.searchText) >= 0)
        filtered.push(m)
    }
    return filtered
  }

  visible: true
  implicitWidth: pill.implicitWidth
  implicitHeight: pill.implicitHeight

  NowPlayingPill {
    id: pill
    bar: root.bar
    tokens: root.tokens
    movieCount: root.movies.length
    active: root.pillActive
    tooltipText: root.tooltipText
    onPressed: function(button) {
      if (button === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: pill
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(600))

    Rectangle {
      anchors.fill: parent
      color: Color.background
      border.color: Color.muted
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(12)
        spacing: Style.space(2)

        // Header row
        RowLayout {
          Layout.fillWidth: true

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              text: "\uD83C\uDFAC Now Playing"
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.labelSize : Style.font.body
              font.bold: true
              color: Color.foreground
            }

            Text {
              text: root.theaterName
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
              color: Color.muted
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Text {
            visible: root.loading
            text: "\u23F3"
            font.family: tokens ? tokens.fontFamily : Style.font.family
            font.pixelSize: tokens ? tokens.labelSize : Style.font.body
            color: Color.accent
          }

          Text {
            text: "\u2699"
            font.family: tokens ? tokens.fontFamily : Style.font.family
            font.pixelSize: tokens ? tokens.labelSize : Style.font.body
            color: root.showTheaterSearch ? Color.foreground : Color.muted

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showTheaterSearch = !root.showTheaterSearch
            }
          }

          Text {
            text: "\u2715"
            font.family: tokens ? tokens.fontFamily : Style.font.family
            font.pixelSize: tokens ? tokens.labelSize : Style.font.body
            color: Color.muted

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        // Theater search section
        Rectangle {
          Layout.fillWidth: true
          visible: root.showTheaterSearch
          Layout.preferredHeight: theaterSearchCol.implicitHeight + Style.space(16)
          color: Color.background
          border.color: Color.muted
          border.width: 1

          ColumnLayout {
            id: theaterSearchCol
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(4)

            Text {
              text: "Find theaters by ZIP code"
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
              color: Color.muted
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)

              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                color: Color.background
                border.color: Color.muted
                border.width: 1

                TextInput {
                  id: zipInput
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  font.family: tokens ? tokens.fontFamily : Style.font.family
                  font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                  color: Color.foreground
                  clip: true
                  maximumLength: 5
                  validator: IntValidator { bottom: 0; top: 99999 }
                  onAccepted: root.service && root.service.searchByZip(zipInput.text)

                  Text {
                    visible: !zipInput.text && !zipInput.activeFocus
                    anchors.fill: parent
                    anchors.margins: Style.space(4)
                    text: "Enter ZIP code"
                    font.family: tokens ? tokens.fontFamily : Style.font.family
                    font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                    color: Color.muted
                    verticalAlignment: Text.AlignVCenter
                  }
                }
              }

              Rectangle {
                Layout.preferredWidth: Style.space(60)
                Layout.preferredHeight: Style.space(28)
                color: zipMouse.containsMouse ? Color.foreground + "22" : Color.background
                border.color: Color.muted
                border.width: 1

                Text {
                  anchors.centerIn: parent
                  text: root.searchingTheaters ? "\u23F3" : "Search"
                  font.family: tokens ? tokens.fontFamily : Style.font.family
                  font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                  color: Color.foreground
                }

                MouseArea {
                  id: zipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.service && root.service.searchByZip(zipInput.text)
                }
              }
            }

            // Theater results
            Repeater {
              model: root.theaters

              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(28)
                color: theaterRowMouse.containsMouse ? Color.foreground + "0D" : Color.background
                border.color: Color.muted
                border.width: 1

                Text {
                  anchors.fill: parent
                  anchors.margins: Style.space(4)
                  text: modelData.name
                  font.family: tokens ? tokens.fontFamily : Style.font.family
                  font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                  color: Color.foreground
                  elide: Text.ElideRight
                  verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                  id: theaterRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.service && root.service.selectTheater(modelData.id, modelData.name)
                    root.showTheaterSearch = false
                    zipInput.text = ""
                  }
                }
              }
            }

            Text {
              visible: root.theaters.length === 0 && !root.searchingTheaters
              text: root.searchingTheaters ? "Searching..." : ""
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
              color: Color.muted
            }
          }
        }

        // Filter bar
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(32)
          color: Color.background
          border.color: Color.muted
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(6)

            Text {
              text: "\uD83D\uDD0D"
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
              color: Color.muted
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              font.family: tokens ? tokens.fontFamily : Style.font.family
              font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
              color: Color.foreground
              clip: true
              onTextChanged: root.searchText = text.toLowerCase()

              Text {
                visible: !searchInput.text && !searchInput.activeFocus
                text: "Filter movies..."
                font.family: tokens ? tokens.fontFamily : Style.font.family
                font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                color: Color.muted
              }
            }
          }
        }

        Text {
          text: {
            var filtered = root.getFilteredMovies()
            return filtered.length + " movie" + (filtered.length !== 1 ? "s" : "") + " showing"
          }
          font.family: tokens ? tokens.fontFamily : Style.font.family
          font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
          color: Color.muted
        }

        // Movie list
        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentHeight: movieColumn.height
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: movieColumn
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              id: movieRepeater
              model: root.getFilteredMovies()

              delegate: Rectangle {
                required property var modelData
                width: movieColumn.width
                height: Style.space(72)
                color: Color.background
                border.color: movieRowMouse.containsMouse ? Color.muted : Color.background
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(4)

                  Rectangle {
                    Layout.preferredWidth: Style.space(50)
                    Layout.fillHeight: true
                    color: Color.background

                    Image {
                      anchors.fill: parent
                      source: modelData.poster || ""
                      fillMode: Image.PreserveAspectFit
                      visible: modelData.poster && modelData.poster.length > 0
                      onStatusChanged: {
                        if (status === Image.Error) visible = false
                      }
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: !modelData.poster || modelData.poster.length === 0
                      text: "\uD83C\uDFAC"
                      font.pixelSize: Style.space(20)
                      color: Color.muted
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(1)

                    Text {
                      Layout.fillWidth: true
                      text: modelData.title || "Unknown"
                      font.family: tokens ? tokens.fontFamily : Style.font.family
                      font.pixelSize: tokens ? tokens.labelSize : Style.font.body
                      font.bold: true
                      color: Color.foreground
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      text: {
                        var parts = []
                        if (modelData.rating) parts.push(modelData.rating)
                        if (modelData.runtime) parts.push(modelData.runtime)
                        return parts.join(" \u00B7 ") || ""
                      }
                      font.family: tokens ? tokens.fontFamily : Style.font.family
                      font.pixelSize: tokens ? tokens.captionSize : Style.font.caption
                      color: Color.muted
                      elide: Text.ElideRight
                    }

                    Flow {
                      Layout.fillWidth: true
                      spacing: Style.space(3)

                      Repeater {
                        model: modelData.showtimes || []

                        Rectangle {
                          required property var modelData
                          width: timeLabel.width + Style.space(6)
                          height: Style.space(18)
                          color: "transparent"
                          border.color: Color.muted
                          border.width: 1

                          Text {
                            id: timeLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.family: tokens ? tokens.fontFamily : Style.font.family
                            font.pixelSize: 9
                            color: Color.muted
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              Qt.openUrlExternally("https://www.fandango.com/movies-in-theaters")
                            }
                          }
                        }
                      }
                    }
                  }
                }

                MouseArea {
                  id: movieRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton
                  onClicked: {
                    if (modelData.id) {
                      Qt.openUrlExternally(
                        "https://www.bigscreen.com/NowShowing.php?movie=" + modelData.id)
                    }
                  }
                }
              }
            }
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Data from bigscreen.com"
          font.family: tokens ? tokens.fontFamily : Style.font.family
          font.pixelSize: 9
          color: Color.muted
        }
      }
    }
  }
}
