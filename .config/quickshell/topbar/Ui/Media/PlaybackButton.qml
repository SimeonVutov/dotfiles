import QtQuick
import qs.Ui
import qs.Common

// Circular transport button that swaps its glyph between play and pause.
Rectangle {
    id: root

    property int diameter: 25
    property color accent: Theme.popupAccent
    property color idleColor: Theme.popupSurface
    property color iconColor: Theme.text
    property int iconSize: 17
    property bool playing: false

    signal clicked

    width: diameter
    height: diameter
    radius: diameter / 2
    color: playing ? accent : idleColor

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    IconButton {
        anchors.centerIn: parent
        icon: root.playing ? Icons.mediaPause : Icons.mediaPlay
        size: root.iconSize
        color: root.iconColor
        enabled: root.enabled
        onClicked: root.clicked()
    }
}
