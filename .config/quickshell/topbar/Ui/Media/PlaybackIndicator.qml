pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import qs.Common

Item {
    id: root
    property bool playing: false
    property int stepDuration: 420
    implicitWidth: 18
    implicitHeight: 20

    Repeater {
        model: 5
        Rectangle {
            id: bar
            required property int index
            x: index * 4
            y: 2
            width: 2
            height: 16
            radius: 1
            color: root.playing ? Theme.popupText : Theme.popupSubtleText

            // A fixed baseline and transform keep motion out of the layout.
            transform: Scale {
                id: level
                origin.y: bar.height
                yScale: 0.18
                SequentialAnimation on yScale {
                    running: root.playing && root.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: [0.45, 0.8, 0.3, 0.65, 0.5][bar.index]
                        duration: root.stepDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: [0.7, 0.4, 0.65, 0.3, 0.75][bar.index]
                        duration: root.stepDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: [0.3, 0.6, 0.85, 0.5, 0.35][bar.index]
                        duration: root.stepDuration
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: [0.55, 0.25, 0.45, 0.8, 0.6][bar.index]
                        duration: root.stepDuration
                        easing.type: Easing.InOutSine
                    }
                    onStopped: level.yScale = 0.18
                }
            }
        }
    }
}
