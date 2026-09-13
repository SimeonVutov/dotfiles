import QtQuick
import qs.Common

Rectangle {
    id: root

    property int diameter: 28
    property int glyphSize: 12
    signal clicked

    width: diameter
    height: diameter
    radius: diameter / 2
    color: hover.containsMouse ? Theme.popupBorder : Theme.popupSurface

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    IconButton {
        id: hover
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        size: root.glyphSize
        icon: Icons.close
        onClicked: root.clicked()
    }
}
