import QtQuick

Item {
    id: root
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool connected: false
    property real reach: 0
    property real breakup: 1
    property real frozenX: 0
    property real frozenY: 0
    property real frozenLength: 0
    property real frozenAngle: 0
    readonly property real length: Math.hypot(endX - startX, endY - startY)
    readonly property real angle: Math.atan2(endY - startY, endX - startX) * 180 / Math.PI

    onConnectedChanged: {
        if (connected)
            extend.restart();
        else if (reach > 0) {
            frozenX = startX;
            frozenY = startY;
            frozenLength = length * reach;
            frozenAngle = angle;
            extend.stop();
            reach = 0;
            shatter.restart();
        }
    }
    NumberAnimation {
        id: extend
        target: root
        property: "reach"
        from: 0
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: shatter
        target: root
        property: "breakup"
        from: 0
        to: 1
        duration: 360
        easing.type: Easing.OutQuad
    }
    Item {
        x: root.startX
        y: root.startY
        rotation: root.angle
        visible: root.connected && root.reach > 0
        Rectangle {
            y: -2
            width: root.length * root.reach
            height: 4
            color: Theme.text
            opacity: .045
        }
        Rectangle {
            y: -.5
            width: root.length * root.reach
            height: 1
            color: Theme.text
            opacity: .36
        }
        Rectangle {
            x: root.length * root.reach - 2
            y: -2
            width: 4
            height: 4
            radius: 2
            color: Theme.text
            opacity: .85
        }
    }
    Item {
        x: root.frozenX
        y: root.frozenY
        rotation: root.frozenAngle
        visible: shatter.running
        Repeater {
            model: 24
            Rectangle {
                required property int index
                x: root.frozenLength * (index / 24) + Math.sin(index * 5.7) * root.breakup * 16
                y: Math.cos(index * 2.4) * root.breakup * (10 + index % 5 * 5)
                width: Math.max(1, root.frozenLength / 24 * .7) * (1 - root.breakup * .7)
                height: index % 3 === 0 ? 1.5 : .8
                rotation: Math.sin(index * 3.1) * root.breakup * 110
                color: Theme.text
                opacity: (1 - root.breakup) * .8
            }
        }
    }
}
