import QtQuick

Item {
    id: root

    property int count: 0
    property color color: "#ffffff"
    property int slots: 0
    property real amount: Math.min(count, 18)
    readonly property real diameter: 12
    readonly property real gap: diameter * .2

    onCountChanged: slots = Math.max(slots, Math.min(count, 18))
    Component.onCompleted: slots = Math.min(count, 18)

    Behavior on amount {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
            onFinished: root.slots = Math.min(root.count, 18)
        }
    }

    Repeater {
        model: root.slots

        delegate: Rectangle {
            required property int index
            readonly property real reveal: Math.max(0, Math.min(1, root.amount - index))
            width: root.diameter
            height: width
            radius: width / 2
            x: root.width / 2 - (root.amount * root.diameter + Math.max(0, root.amount - 1) * root.gap) / 2 + index * (root.diameter + root.gap)
            y: (root.height - height) / 2
            scale: .3 + .7 * reveal
            opacity: reveal
            color: root.color
        }
    }
}
