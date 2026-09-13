import QtQuick
import QtQuick.Layouts
import qs.Common

FocusScope {
    id: root

    default property alias content: body.data
    property string title: ""
    property bool presenting: false
    property real reveal: 0
    property int panelWidth: 900
    property int panelHeight: 620
    readonly property int padding: 26
    readonly property real unfold: Math.max(0, Math.min(1, (reveal - .12) / .76))
    signal closeRequested
    signal closed

    onPresentingChanged: {
        transition.to = presenting ? 1 : 0;
        transition.duration = presenting ? 700 : 250;
        transition.restart();
        if (presenting)
            forceActiveFocus();
    }

    Keys.onEscapePressed: event => {
        root.closeRequested();
        event.accepted = true;
    }

    NumberAnimation {
        id: transition
        target: root
        property: "reveal"
        easing.type: Easing.InOutCubic
        onFinished: if (!root.presenting)
            root.closed()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayAbyss
        opacity: root.reveal * .68
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Item {
        id: stage
        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        scale: Math.min(1, (root.width - 32) / width, (root.height - 32) / height)

        Rectangle {
            id: panel
            width: parent.width * (.015 + .985 * root.unfold)
            height: parent.height
            anchors.centerIn: parent
            radius: 24
            opacity: Math.min(1, root.reveal * 5)
            color: Theme.overlaySurface
            border.color: Theme.overlayBorder
            clip: true

            MouseArea {
                anchors.fill: parent
            }

            Item {
                width: stage.width
                height: stage.height
                anchors.centerIn: parent
                opacity: Math.max(0, (root.unfold - .35) / .65)

                RowLayout {
                    id: header
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: root.padding
                    }
                    height: 64
                    spacing: 18

                    Column {
                        Layout.fillWidth: true
                        spacing: 6
                        BarText {
                            text: root.title
                            color: Theme.overlayText
                            font.pixelSize: 26
                        }
                    }
                    Item {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 64
                    }
                    CloseButton {
                        onClicked: root.closeRequested()
                    }
                }

                Item {
                    id: body
                    anchors {
                        top: header.bottom
                        topMargin: 30
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: root.padding
                    }
                    enabled: root.presenting && root.unfold > .85
                }
            }
        }

        Item {
            id: antenna
            width: 64
            height: 64
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 * (1 - root.unfold) + root.padding * root.unfold
            opacity: Math.min(1, root.reveal * 8)
            property real bearing: 0

            SequentialAnimation on bearing {
                running: root.presenting
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

            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.overlayMuted;
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
                rotation: antenna.bearing
                transformOrigin: Item.Center
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Theme.overlayText;
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
                        ctx.fillStyle = Theme.overlayText;
                        ctx.fill();
                    }
                }
                Repeater {
                    model: 3
                    Canvas {
                        required property int index
                        anchors.fill: parent
                        readonly property real phase: (wave.progress + index / 3) % 1
                        transform: Scale {
                            origin.x: 32
                            origin.y: 15
                            xScale: .6 + phase * 1.4
                            yScale: xScale
                        }
                        opacity: (1 - phase) * .65
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = Theme.overlayMuted;
                            ctx.lineWidth = 1;
                            ctx.beginPath();
                            ctx.arc(32, 15, 13, -2.4, -.74);
                            ctx.stroke();
                        }
                    }
                }
            }

            Item {
                id: wave
                property real progress: 0
                NumberAnimation on progress {
                    running: root.presenting
                    loops: Animation.Infinite
                    from: 0
                    to: 1
                    duration: 1600
                }
            }
        }

        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: stage.width / 2 + (index === 0 ? -1 : 1) * panel.width / 2 - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: stage.height - 48
                color: Theme.overlayText
                opacity: (1 - root.unfold) * Math.min(1, root.reveal * 10) * .65
                visible: transition.running
            }
        }
    }
}
