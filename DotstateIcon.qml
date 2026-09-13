import QtQuick
import qs.Commons

// Single Nerd Font sync glyph, colored per state by the caller. Modeled after
// the simpler glyph-based icons (e.g. SystemUpdate's refresh icon) rather than
// a hand-drawn Shape -- there's no brand mark to reproduce here.
Text {
  id: root

  property real iconSize: Style.font.icon

  textFormat: Text.PlainText
  text: ""
  font.pixelSize: iconSize
  color: Color.foreground
  verticalAlignment: Text.AlignVCenter
  horizontalAlignment: Text.AlignHCenter
}
