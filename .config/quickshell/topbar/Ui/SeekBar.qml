import QtQuick
import qs.Common
import qs.Services

// Playback timeline. Click or drag anywhere on it to seek; while dragging it
// shows where you're heading rather than where the track actually is.
Item {
    id: root

    property real trackHeight: 4
    property bool interactive: Players.canSeek && Players.length > 0

    // Ratio the player reports, or the one being dragged to.
    readonly property real playbackRatio: Players.length > 0 ? Math.max(0, Math.min(1, Players.position / Players.length)) : 0
    property real dragRatio: -1
    readonly property real ratio: dragRatio >= 0 ? dragRatio : playbackRatio

    implicitHeight: 14

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: Theme.popupSurface
    }

    Rectangle {
        id: fill
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(track.width, track.width * root.ratio))
        height: root.trackHeight
        radius: height / 2
        color: Theme.popupAccent

        Behavior on width {
            enabled: root.dragRatio < 0
            NumberAnimation {
                duration: 120
                easing.type: Easing.Linear
            }
        }
    }

    Rectangle {
        id: playhead
        width: 10
        height: 10
        radius: 5
        color: Theme.popupAccent
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(track.width, track.width * root.ratio)) - width / 2

        scale: mouseArea.containsMouse || root.dragRatio >= 0 ? 1 : 0
        opacity: scale

        Behavior on x {
            enabled: root.dragRatio < 0
            NumberAnimation {
                duration: 120
                easing.type: Easing.Linear
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function ratioAt(x) {
            return Math.max(0, Math.min(1, (x + 6) / root.width));
        }

        onPressed: mouse => root.dragRatio = ratioAt(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                root.dragRatio = ratioAt(mouse.x);
        }
        onReleased: {
            if (root.dragRatio >= 0)
                Players.seekToFraction(root.dragRatio);
            root.dragRatio = -1;
        }
        onCanceled: root.dragRatio = -1
    }
}
