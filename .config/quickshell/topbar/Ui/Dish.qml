import QtQuick
import qs.Common

// Ground-station antenna emblem. Drawn in a fixed 64-unit frame and scaled to
// whatever size it is given; it slews back and forth and keeps transmitting
// for as long as it is shown.
Item {
    id: root

    property bool transmitting: false
    property real bearing: 0

    readonly property real unit: Math.min(width, height) / 64

    SequentialAnimation on bearing {
        running: root.transmitting
        loops: Animation.Infinite
        NumberAnimation {
            to: 8
            duration: 2300
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: -8
            duration: 2300
            easing.type: Easing.InOutSine
        }
    }

    // The pad stays level; only the reflector slews.
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(root.unit, root.unit);
            ctx.strokeStyle = Theme.popupSubtleText;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(20, 57);
            ctx.lineTo(43, 57);
            ctx.moveTo(25, 57);
            ctx.lineTo(32, 40);
            ctx.lineTo(39, 57);
            ctx.stroke();
        }
    }

    Item {
        anchors.fill: parent
        rotation: root.bearing
        transformOrigin: Item.Center

        Canvas {
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(root.unit, root.unit);
                ctx.strokeStyle = Theme.popupText;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.moveTo(10, 27);
                ctx.quadraticCurveTo(32, 55, 54, 27);
                ctx.lineTo(10, 27);
                ctx.moveTo(17, 32);
                ctx.lineTo(32, 15);
                ctx.lineTo(47, 32);
                ctx.moveTo(32, 15);
                ctx.lineTo(32, 38);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(32, 15, 2, 0, Math.PI * 2);
                ctx.fillStyle = Theme.popupText;
                ctx.fill();
            }
        }

        Repeater {
            model: 3

            Canvas {
                required property int index

                readonly property real phase: (pulse.progress + index / 3) % 1

                anchors.fill: parent
                opacity: (1 - phase) * .65
                transform: Scale {
                    origin.x: root.unit * 32
                    origin.y: root.unit * 15
                    xScale: .6 + phase * 1.4
                    yScale: xScale
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(root.unit, root.unit);
                    ctx.strokeStyle = Theme.popupSubtleText;
                    ctx.lineWidth = 1;
                    ctx.beginPath();
                    ctx.arc(32, 15, 13, -2.4, -.74);
                    ctx.stroke();
                }
            }
        }
    }

    QtObject {
        id: pulse

        property real progress: 0
    }

    NumberAnimation {
        target: pulse
        property: "progress"
        from: 0
        to: 1
        duration: 1600
        loops: Animation.Infinite
        running: root.transmitting
    }
}
