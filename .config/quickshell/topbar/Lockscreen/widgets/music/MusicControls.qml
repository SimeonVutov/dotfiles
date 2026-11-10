pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Ui
import qs.Core.Media

Item {
    id: root

    required property Player player
    property color textColor: "#ffffff"

    implicitWidth: 208
    implicitHeight: 56

    component TransportButton: Rectangle {
        id: button

        property string icon: ""
        property bool primary: false
        signal clicked

        width: primary ? 56 : 44
        height: width
        radius: width / 2
        opacity: enabled ? 1 : .4
        color: primary ? "#ffffff" : action.containsMouse ? "#50000000" : "#26000000"
        border.width: primary ? 0 : 1
        border.color: "#25ffffff"

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }

        IconButton {
            id: action
            anchors.fill: parent
            icon: button.icon
            size: button.primary ? 25 : 20
            color: button.primary ? "#101014" : root.textColor
            disabledOpacity: 1
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 28

        TransportButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.mediaPrevious
            enabled: root.player.canGoPrevious
            onClicked: root.player.previous()
        }

        TransportButton {
            primary: true
            icon: root.player.isPlaying ? Icons.mediaPause : Icons.mediaPlay
            enabled: !!root.player.activePlayer && root.player.activePlayer.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }

        TransportButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Icons.mediaNext
            enabled: root.player.canGoNext
            onClicked: root.player.next()
        }
    }
}
