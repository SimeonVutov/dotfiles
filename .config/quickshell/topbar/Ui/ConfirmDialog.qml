import QtQuick
import qs.Common

// A generic two-choice confirmation, with an optional self-reverting countdown.
FocusScope {
    id: root

    property bool open: false
    property bool showCountdown: true
    property string title: ""
    property string message: ""
    property string acceptText: "Keep"
    property string rejectText: "Revert"
    property int seconds: 0
    property int total: 1
    readonly property real remaining: Math.max(0, Math.min(1, seconds / Math.max(total, 1)))

    signal accepted
    signal rejected

    visible: opacity > .01
    opacity: open ? 1 : 0
    focus: open

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFast
        }
    }

    onOpenChanged: if (open)
        forceActiveFocus()

    Keys.onEscapePressed: event => {
        root.rejected();
        event.accepted = true;
    }
    Keys.onReturnPressed: event => {
        root.accepted();
        event.accepted = true;
    }
    Keys.onEnterPressed: event => {
        root.accepted();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.overlayAbyss
        opacity: .82
        MouseArea {
            anchors.fill: parent
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 420)
        height: column.implicitHeight + 56
        radius: Theme.popupRadius
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        scale: root.open ? 1 : .93

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationNormal
                easing.type: Easing.OutBack
            }
        }

        Column {
            id: column

            anchors.centerIn: parent
            width: parent.width - 56
            spacing: 18

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                visible: root.showCountdown

                Canvas {
                    id: ring

                    anchors.fill: parent
                    property real progress: root.remaining

                    Behavior on progress {
                        NumberAnimation {
                            duration: 1000
                            easing.type: Easing.Linear
                        }
                    }

                    onProgressChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        const radius = width / 2 - 5;
                        ctx.clearRect(0, 0, width, height);
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = Theme.popupBorder;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, radius, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.strokeStyle = Theme.popupText;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
                        ctx.stroke();
                    }
                }

                BarText {
                    anchors.centerIn: parent
                    text: root.seconds
                    color: Theme.popupText
                    font.pixelSize: Theme.fontSizeDisplay
                }
            }

            BarText {
                width: parent.width
                text: root.title
                color: Theme.popupText
                font.pixelSize: Theme.fontSizeLarge
                horizontalAlignment: Text.AlignHCenter
            }

            BarText {
                width: parent.width
                text: root.message
                visible: root.message.length > 0
                color: Theme.popupSubtleText
                font.pixelSize: Theme.fontSizeCaption
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                ConnectionButton {
                    width: 150
                    implicitHeight: 40
                    text: root.rejectText
                    onClicked: root.rejected()
                }

                ConnectionButton {
                    width: 150
                    implicitHeight: 40
                    text: root.acceptText
                    checked: true
                    onClicked: root.accepted()
                }
            }
        }
    }
}
