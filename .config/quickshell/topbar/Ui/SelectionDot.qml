import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool selected: false
    property int size: 16

    width: size
    height: size
    radius: size / 2
    color: "transparent"
    border.color: root.selected ? Theme.popupAccent : Theme.popupSubtleText

    Rectangle {
        anchors.centerIn: parent
        width: parent.width / 2
        height: parent.height / 2
        radius: width / 2
        color: Theme.popupAccent
        opacity: root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
            }
        }
    }
}
