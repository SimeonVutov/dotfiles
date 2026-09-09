import QtQuick
import qs.Common

// The rounded capsule every module sits in. Reproduces the old waybar module
// box model: black at 80%, 15px radius, 15px of horizontal padding, and a
// fixed height so every pill lines up.
Rectangle {
    id: root

    default property alias content: contentItem.data

    // Alert states tint the whole pill (battery low, temperature critical).
    property color background: Theme.pillBackground
    property real backgroundOpacity: Theme.pillOpacity
    property int paddingH: Theme.pillPaddingH
    property bool animateWidth: true

    implicitWidth: contentItem.width + paddingH * 2
    implicitHeight: Theme.barHeight - Theme.pillMarginV * 2

    radius: Theme.pillRadius
    color: background
    opacity: backgroundOpacity
    clip: true

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationNormal
            easing.type: Theme.easing
        }
    }

    Behavior on implicitWidth {
        enabled: root.animateWidth
        NumberAnimation {
            duration: Theme.durationNormal
            easing.type: Theme.easingEmphasized
        }
    }

    Item {
        id: contentItem
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
