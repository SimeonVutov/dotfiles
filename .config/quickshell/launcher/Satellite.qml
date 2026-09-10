import QtQuick

Item {
    id: root
    required property int slot
    property var entry: null
    property var pendingEntry: null
    property bool selected: false
    property bool tracking: false
    property real presence: 0
    property real swayX: 0
    property real swayY: 0
    property real tilt: 0
    property real focusScale: selected ? 1.07 : 1

    readonly property bool accepted: pendingEntry !== null && entry === pendingEntry
    // Two widely separated rings, staggered so nothing lines up radially.
    readonly property bool inner: slot < 6
    readonly property real angle: ((slot % 6) * 60 + (inner ? -90 : -60)) * Math.PI / 180
    readonly property real destinationX: Math.cos(angle) * (inner ? 420 : 700) + swayX
    readonly property real destinationY: Math.sin(angle) * (inner ? 285 : 418) + swayY
    readonly property real distance: Math.hypot(destinationX, destinationY)
    signal chosen(var app)

    function target(app) {
        if (app === pendingEntry)
            return;
        pendingEntry = app;
        if (app === entry && app) {
            retire.stop();
            appear.restart();
        } else if (presence > .001) {
            appear.stop();
            if (!retire.running)
                retire.start();
        } else
            install();
    }
    function install() {
        // Retain invisible entries so backspacing can reclaim their old slot.
        if (pendingEntry) {
            entry = pendingEntry;
            appear.restart();
        }
    }
    Behavior on focusScale {
        NumberAnimation {
            duration: Theme.motion
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation {
        id: appear
        target: root
        property: "presence"
        to: 1
        duration: 620
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: retire
        target: root
        property: "presence"
        to: 0
        duration: 420
        easing.type: Easing.InCubic
        onFinished: root.install()
    }
    SequentialAnimation on swayX {
        running: root.visible && root.presence > .001
        loops: Animation.Infinite
        NumberAnimation {
            to: 16
            duration: 3500 + root.slot * 127
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -16
            duration: 3500 + root.slot * 127
            easing.type: Easing.InOutSine
        }
    }
    SequentialAnimation on swayY {
        running: root.visible && root.presence > .001
        loops: Animation.Infinite
        NumberAnimation {
            to: -13
            duration: 4100 + root.slot * 193
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 13
            duration: 4100 + root.slot * 193
            easing.type: Easing.InOutSine
        }
    }
    SequentialAnimation on tilt {
        running: root.visible && root.presence > .001
        loops: Animation.Infinite
        NumberAnimation {
            to: 4
            duration: 5200 + root.slot * 211
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -4
            duration: 5200 + root.slot * 211
            easing.type: Easing.InOutSine
        }
    }

    LaserLink {
        startX: root.width / 2 + root.destinationX / root.distance * 150
        startY: root.height / 2 + root.destinationY / root.distance * 150
        endX: root.width / 2 + root.destinationX
        endY: root.height / 2 + root.destinationY
        connected: root.tracking && root.accepted && root.presence > .02
    }
    Item {
        id: craft
        x: root.width / 2 + root.destinationX - width / 2
        y: root.height / 2 + root.destinationY - height / 2
        width: 168
        height: 122
        visible: root.entry !== null && root.presence > 0
        opacity: root.presence
        scale: root.focusScale

        SatelliteMesh {
            id: mesh
            width: 156
            height: 94
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            rotation: root.swayX * .18 + root.tilt
            yaw: root.slot % 2 ? .3 : -.3
            icon: root.entry?.icon || ""
            fallback: root.entry?.name?.charAt(0) || ""
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 30
            width: 46
            height: 50
            radius: 6
            color: "transparent"
            border.color: root.selected ? Theme.text : Theme.border
            opacity: root.selected || mouse.containsMouse ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.motion
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.motion
                }
            }
        }
        Text {
            y: 104
            width: parent.width
            text: root.entry?.name || ""
            textFormat: Text.PlainText
            font.family: Theme.font
            font.pixelSize: 12
            color: root.selected || mouse.containsMouse ? Theme.text : Theme.muted
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            Behavior on color {
                ColorAnimation {
                    duration: Theme.motion
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.accepted && root.presence > .15
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chosen(root.entry)
        }
    }
}
