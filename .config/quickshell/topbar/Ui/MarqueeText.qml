import QtQuick
import qs.Common

Item {
    id: root

    property string text: ""
    property string restartKey: text
    property color color: Theme.text
    property int fontSize: Theme.fontSize
    property int pixelsPerSecond: 32
    property int startPause: 1100
    property int endPause: 700
    property int repeatGap: 36

    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    readonly property bool shouldScroll: overflow > 1

    implicitHeight: label.implicitHeight
    clip: true

    function restart() {
        scroll.stop();
        ticker.x = 0;
        if (shouldScroll && visible)
            scroll.start();
    }

    onTextChanged: Qt.callLater(restart)
    onRestartKeyChanged: Qt.callLater(restart)
    onWidthChanged: Qt.callLater(restart)
    onVisibleChanged: restart()

    Item {
        id: ticker
        anchors.verticalCenter: parent.verticalCenter
        width: label.implicitWidth * 2 + root.repeatGap
        height: label.implicitHeight

        BarText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.color
            font.pixelSize: root.fontSize
            wrapMode: Text.NoWrap

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationFast
                }
            }
        }

        BarText {
            x: label.implicitWidth + root.repeatGap
            anchors.verticalCenter: parent.verticalCenter
            visible: root.shouldScroll
            text: root.text
            color: root.color
            font.pixelSize: root.fontSize
            wrapMode: Text.NoWrap

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durationFast
                }
            }
        }
    }

    SequentialAnimation {
        id: scroll

        loops: Animation.Infinite

        PauseAnimation {
            duration: root.startPause
        }
        NumberAnimation {
            target: ticker
            property: "x"
            from: 0
            to: -root.overflow
            duration: Math.max(1, Math.round(root.overflow / root.pixelsPerSecond * 1000))
            easing.type: Easing.Linear
        }
        PauseAnimation {
            duration: root.endPause
        }
        NumberAnimation {
            target: ticker
            property: "x"
            from: -root.overflow
            to: -(label.implicitWidth + root.repeatGap)
            duration: Math.max(1, Math.round((root.width + root.repeatGap) / root.pixelsPerSecond * 1000))
            easing.type: Easing.Linear
        }
        PropertyAction {
            target: ticker
            property: "x"
            value: 0
        }
    }
}
