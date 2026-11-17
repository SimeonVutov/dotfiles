import QtQuick
import qs.Ui
import qs.Common
import qs.Core.Media

Rectangle {
    id: root

    required property Player player

    property bool expanded: false
    readonly property bool hasSources: root.player.allPlayers.length > 0
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
        font.pixelSize: Theme.fontSizeLarge
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
            font.pixelSize: Theme.fontSizeTiny
        }
        BarText {
            width: parent.width
            text: root.hasSources ? ((root.player.manualPlayerId ? "" : "Automatic · ") + (root.player.identity || "Choose source")) : "No media sources"
            font.pixelSize: Theme.fontSizeLabel
            elide: Text.ElideRight
        }
    }
    BarText {
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: Icons.chevronDown
        font.pixelSize: Theme.fontSizeTiny
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
