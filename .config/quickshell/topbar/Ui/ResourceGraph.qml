import QtQuick
import qs.Common
import qs.Services

Item {
    id: root

    required property string metric
    required property string label
    required property string valueLabel
    required property color accent
    property string icon: ""
    property real maximum: 100
    property bool consuming: false
    readonly property bool graphEnabled: !!Config.hardwareGraphs[metric]
    readonly property bool watching: consuming && graphEnabled

    implicitHeight: graphEnabled ? 78 : 30
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easingEmphasized
        }
    }

    Subscriber {
        active: root.watching
        onToggled: enabled => SysMon.watchGraph(root.metric, enabled)
    }

    Item {
        width: parent.width
        height: 30

        Rectangle {
            width: 4
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: root.graphEnabled ? root.accent : Theme.popupSubtleText
        }

        BarText {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon ? root.icon + "  " + root.label : root.label
            color: root.graphEnabled ? Theme.popupText : Theme.popupSubtleText
            font.pixelSize: Theme.fontSizeLabel
        }

        BarText {
            anchors.right: toggle.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.graphEnabled ? root.valueLabel : "Hidden"
            color: root.graphEnabled ? Theme.popupText : Theme.popupSubtleText
            font.pixelSize: Theme.fontSizeLabel
        }

        ToggleSwitch {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            trackWidth: 28
            knobOnX: 14
            on: root.graphEnabled
            onColor: Qt.alpha(root.accent, 0.25)
            knobOnColor: Theme.popupAccent
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.toggleHardwareGraph(root.metric)
        }
    }

    Rectangle {
        x: 0
        y: 30
        width: parent.width
        height: 42
        radius: 9
        color: Theme.popupSurface
        visible: root.graphEnabled

        StripChart {
            anchors.fill: parent
            anchors.margins: 8
            active: root.watching
            samples: SysMon.histories[root.metric]
            accent: root.accent
            maximum: root.maximum
        }
    }
}
