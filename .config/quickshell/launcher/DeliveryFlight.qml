import QtQuick
import Quickshell

// The chosen app's icon flying back down the satellite's laser into the globe,
// followed by an impact ring. Endpoints are live, so it tracks a drifting
// satellite for the whole trip.
Item {
    id: root

    property bool launching: false
    property bool sceneVisible: false
    property real progress: 0
    property real settled: 0
    property point origin: Qt.point(0, 0)
    property point destination: Qt.point(0, 0)
    property real startSize: Theme.iconSize
    property string icon: ""
    property string label: ""

    Item {
        id: capsule

        readonly property real t: root.progress
        readonly property real arrivalSize: 38
        readonly property real shellPadding: 8
        readonly property real shellRadius: 12
        readonly property real iconResolution: 64
        readonly property real glyphRatio: .6
        readonly property real fadeFrom: .85

        visible: root.launching && root.sceneVisible
        width: root.startSize + (arrivalSize - root.startSize) * t
        height: width
        x: root.origin.x * (1 - t) + root.destination.x * t - width / 2
        y: root.origin.y * (1 - t) + root.destination.y * t - height / 2
        opacity: root.settled * (1 - Math.max(0, (t - fadeFrom) / (1 - fadeFrom)))

        Rectangle {
            anchors.fill: parent
            anchors.margins: -capsule.shellPadding
            radius: capsule.shellRadius
            color: Theme.surface
            border.color: Theme.text
        }

        Image {
            anchors.fill: parent
            source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
            sourceSize.width: capsule.iconResolution
            sourceSize.height: capsule.iconResolution

            Text {
                anchors.centerIn: parent
                visible: parent.status !== Image.Ready
                text: root.label.charAt(0)
                color: Theme.text
                font.pixelSize: parent.width * capsule.glyphRatio
            }
        }
    }

    Rectangle {
        id: impact

        readonly property real startsAt: .65
        readonly property real minSize: 30
        readonly property real maxSize: 220
        readonly property real peakOpacity: .55
        readonly property real pulse: Math.max(0, (root.progress - startsAt) / (1 - startsAt))

        visible: root.launching && root.progress > startsAt
        x: root.destination.x - width / 2
        y: root.destination.y - height / 2
        width: minSize + (maxSize - minSize) * pulse
        height: width
        radius: width / 2
        color: "transparent"
        border.color: Theme.text
        opacity: Math.sin(pulse * Math.PI) * peakOpacity * root.settled
    }
}
