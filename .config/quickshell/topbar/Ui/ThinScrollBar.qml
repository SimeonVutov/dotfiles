import QtQuick
import QtQuick.Controls.Basic
import qs.Common

ScrollBar {
    id: root

    readonly property int gutter: 9

    policy: ScrollBar.AsNeeded
    width: 3
    contentItem: Rectangle {
        radius: width / 2
        color: Theme.popupSubtleText
        opacity: root.active ? 0.8 : 0.35
    }
    background: Item {}
}
