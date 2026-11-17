import QtQuick
import qs.Common

Rectangle {
    id: root

    property int diameter: 28
    property int glyphSize: 12
    property string icon: Icons.close
    readonly property bool hovered: hover.containsMouse
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

    Text {
        anchors.fill: parent
        text: root.icon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fontFamily
        font.pixelSize: root.glyphSize
        color: Theme.popupText
        renderType: Text.QtRendering
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
