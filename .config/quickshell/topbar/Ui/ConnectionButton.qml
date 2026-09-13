import QtQuick
import QtQuick.Controls.Basic
import qs.Common

Button {
    id: root

    property bool subtle: false

    implicitHeight: 30
    implicitWidth: Math.max(54, contentItem.implicitWidth + 20)
    padding: 10
    topPadding: 4
    bottomPadding: 4
    hoverEnabled: true
    opacity: enabled ? 1 : 0.4

    contentItem: BarText {
        text: root.text
        font.pixelSize: Theme.fontSizeCaption
        color: root.checked ? Theme.popupBackground : Theme.popupText
        horizontalAlignment: Text.AlignHCenter
    }

    background: Rectangle {
        radius: 9
        color: root.checked ? Theme.popupAccent : root.down || root.hovered ? Theme.popupBorder : root.subtle ? "transparent" : Theme.popupSurface
        border.color: root.activeFocus ? Theme.popupAccent : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
    }
}
