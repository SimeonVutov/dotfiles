import QtQuick
import qs.Common

// An on/off track with a sliding knob, shared by RadioToggle and ResourceGraph.
Rectangle {
    id: root

    property bool on: false
    property color onColor: Theme.popupAccent
    property color offColor: Theme.popupBorder
    property color knobOnColor: Theme.popupBackground
    property color knobOffColor: Theme.popupSubtleText
    property int trackWidth: 30
    property int knobOnX: 17
    property int knobEasing: Easing.Linear
    property bool animateTrackColor: false

    width: trackWidth
    height: 16
    radius: 8
    color: root.on ? root.onColor : root.offColor

    Behavior on color {
        enabled: root.animateTrackColor
        ColorAnimation {
            duration: Theme.durationFast
        }
    }

    Rectangle {
        x: root.on ? root.knobOnX : 3
        y: 3
        width: 10
        height: 10
        radius: 5
        color: root.on ? root.knobOnColor : root.knobOffColor

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: root.knobEasing
            }
        }
    }
}
