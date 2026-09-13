import QtQuick

Item {
    id: root

    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool connected: false

    property real reach: 0
    property real scatter: 1

    readonly property real length: Math.hypot(endX - startX, endY - startY)
    readonly property real angle: Math.atan2(endY - startY, endX - startX) * 180 / Math.PI

    // The beam is snapshotted where it broke, so the debris scatters from that
    // spot instead of trailing the satellite that has already drifted on.
    property real frozenX: 0
    property real frozenY: 0
    property real frozenLength: 0
    property real frozenAngle: 0

    onConnectedChanged: {
        extend.stop();
        burst.stop();

        if (connected) {
            scatter = 1;
            extend.from = reach;
            extend.start();
            return;
        }

        if (reach <= 0)
            return;

        frozenX = startX;
        frozenY = startY;
        frozenLength = length * reach;
        frozenAngle = angle;
        reach = 0;
        scatter = 0;
        burst.restart();
    }

    NumberAnimation {
        id: extend

        target: root
        property: "reach"
        to: 1
        duration: Theme.beamExtendDuration
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: burst

        target: root
        property: "scatter"
        to: 1
        duration: Theme.beamBurstDuration
        easing.type: Easing.OutQuad
    }

    Item {
        id: line

        readonly property real tip: root.length * root.reach
        readonly property real trailOpacity: .32
        readonly property real tipSize: 4
        readonly property real tipOpacity: .8

        x: root.startX
        y: root.startY
        rotation: root.angle
        visible: root.connected && root.reach > 0

        Rectangle {
            y: -height / 2
            width: line.tip
            height: 1
            color: Theme.text
            opacity: line.trailOpacity
        }

        Rectangle {
            x: line.tip - width / 2
            y: -height / 2
            width: line.tipSize
            height: width
            radius: width / 2
            color: Theme.text
            opacity: line.tipOpacity
        }
    }

    Item {
        id: debris

        readonly property int count: 14

        // Shards fall into lanes of growing offset from the beam axis.
        readonly property int lanes: 4
        readonly property real laneSpread: 8
        readonly property real laneStep: 4
        readonly property real spreadAlong: 14
        readonly property real spin: 90

        readonly property real shardRatio: .6
        readonly property real shardShrink: .7
        readonly property real peakOpacity: .7

        readonly property real slideFrequency: 5.1
        readonly property real driftFrequency: 2.6
        readonly property real spinFrequency: 3.3

        x: root.frozenX
        y: root.frozenY
        rotation: root.frozenAngle
        visible: burst.running

        Repeater {
            model: debris.count

            Rectangle {
                required property int index

                readonly property real slot: root.frozenLength * (index / debris.count)
                readonly property real spreadAcross: debris.laneSpread + index % debris.lanes * debris.laneStep

                x: slot + Math.sin(index * debris.slideFrequency) * root.scatter * debris.spreadAlong
                y: Math.cos(index * debris.driftFrequency) * root.scatter * spreadAcross
                rotation: Math.sin(index * debris.spinFrequency) * root.scatter * debris.spin
                width: Math.max(1, root.frozenLength / debris.count * debris.shardRatio) * (1 - root.scatter * debris.shardShrink)
                height: 1
                color: Theme.text
                opacity: (1 - root.scatter) * debris.peakOpacity
            }
        }
    }
}
