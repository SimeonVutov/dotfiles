import QtQuick
import qs.Common

// Text in the bar's font. Plain text only — no markup parsing, which is both
// faster and means titles containing "&" or "<" render as typed.
Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pointSize: -1
    font.pixelSize: Theme.fontSize
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationNormal
            easing.type: Theme.easing
        }
    }
}
