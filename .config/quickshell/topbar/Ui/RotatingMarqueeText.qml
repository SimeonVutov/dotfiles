import QtQuick
import qs.Common

Item {
    id: root

    property var texts: []
    property color color: Theme.text
    property int fontSize: Theme.fontSizeSmall
    property int endPause: 0
    property int currentIndex: 0
    readonly property string textsKey: texts.join("\u001f")
    readonly property int dwellTime: current.shouldScroll ? Math.min(18000, Math.max(7000, current.cycleDuration * 2)) : 3800

    implicitHeight: current.implicitHeight
    clip: true

    function reset() {
        transition.stop();
        currentIndex = 0;
        current.text = texts.length > 0 ? texts[0] : "";
        current.y = 0;
        current.opacity = 1;
        next.y = height;
        next.opacity = 0;
    }

    function advance() {
        if (texts.length < 2)
            return;
        transition.nextIndex = (currentIndex + 1) % texts.length;
        next.text = texts[transition.nextIndex];
        next.y = height;
        next.opacity = 0;
        transition.start();
    }

    onTextsKeyChanged: reset()
    onVisibleChanged: if (!visible)
        reset()
    Component.onCompleted: reset()

    MarqueeText {
        id: current
        width: parent.width
        color: root.color
        fontSize: root.fontSize
        endPause: root.endPause
    }

    MarqueeText {
        id: next
        width: parent.width
        color: root.color
        fontSize: root.fontSize
        endPause: root.endPause
        visible: transition.running
    }

    Timer {
        interval: root.dwellTime
        repeat: true
        running: root.visible && root.texts.length > 1 && !transition.running
        onTriggered: root.advance()
    }

    SequentialAnimation {
        id: transition
        property int nextIndex: 0

        ParallelAnimation {
            NumberAnimation {
                target: current
                property: "y"
                to: -root.height
                duration: Theme.durationNormal
                easing.type: Theme.easingEmphasized
            }
            NumberAnimation {
                target: current
                property: "opacity"
                to: 0
                duration: Theme.durationFast
            }
            NumberAnimation {
                target: next
                property: "y"
                to: 0
                duration: Theme.durationNormal
                easing.type: Theme.easingEmphasized
            }
            NumberAnimation {
                target: next
                property: "opacity"
                to: 1
                duration: Theme.durationFast
            }
        }
        ScriptAction {
            script: {
                root.currentIndex = transition.nextIndex;
                current.text = next.text;
                current.y = 0;
                current.opacity = 1;
                next.y = root.height;
                next.opacity = 0;
            }
        }
    }
}
