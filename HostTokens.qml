pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons

Item {
  id: root

  property var bar: null

  readonly property string fontFamily: bar
    && "fontFamily" in bar && String(bar.fontFamily || "") !== ""
    ? String(bar.fontFamily) : Style.font.family

  readonly property int labelSize: Style.font.body
  readonly property int captionSize: Style.font.caption
  readonly property int iconSize: Style.space(15)

  readonly property int barHeight: bar
    && "barSize" in bar && Number(bar.barSize) > 0
    ? Number(bar.barSize) : Style.space(35)
  readonly property bool vertical: bar ? !!bar.vertical : false

  readonly property color paper: bar && "background" in bar
    ? bar.background : Color.background
  readonly property color ink: bar && "foreground" in bar
    ? bar.foreground : Color.foreground
  readonly property color seal: bar && "urgent" in bar
    ? bar.urgent : Color.urgent
  readonly property color mutedInk: Color.muted

  function widgetContentColor(settings, fallback) {
    return fallback
  }

  visible: false
  width: 0
  height: 0
}
