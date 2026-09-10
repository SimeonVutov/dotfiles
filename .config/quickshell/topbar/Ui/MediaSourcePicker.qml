import QtQuick
import qs.Common
import qs.Services

Rectangle {
    id: root

    property bool expanded: false
    readonly property bool hasSources: Players.allPlayers.length > 0
    implicitHeight: 56
    radius: 10
    color: trigger.containsMouse && hasSources ? Theme.popupBorder : Theme.popupSurface

    onHasSourcesChanged: if (!hasSources)
        expanded = false
    onVisibleChanged: if (!visible)
        expanded = false
    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    BarText {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.music
        font.pixelSize: 18
        color: Theme.popupSubtleText
    }
    Column {
        x: 44
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 36
        spacing: 3

        BarText {
            text: "Media source"
            color: Theme.popupSubtleText
            font.pixelSize: 11
        }
        BarText {
            width: parent.width
            text: root.hasSources ? ((Players.manualPlayerId ? "" : "Automatic · ") + (Players.identity || "Choose source")) : "No media sources"
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }
    BarText {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.chevronDown
        font.pixelSize: 11
        visible: root.hasSources
    }
    MouseArea {
        id: trigger
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.hasSources
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = true
    }
}
