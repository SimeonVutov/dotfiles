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
    property bool subscribed: false

    implicitHeight: graphEnabled ? 78 : 30
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.durationFast
            easing.type: Theme.easingEmphasized
        }
    }

    function syncSubscription() {
        if (subscribed === watching)
            return;
        SysMon.watchGraph(metric, watching);
        subscribed = watching;
    }

    onWatchingChanged: syncSubscription()
    Component.onCompleted: syncSubscription()
    Component.onDestruction: if (subscribed)
        SysMon.watchGraph(metric, false)

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
            font.pixelSize: 13
        }

        BarText {
            anchors.right: toggle.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: root.graphEnabled ? root.valueLabel : "Hidden"
            color: root.graphEnabled ? Theme.popupText : Theme.popupSubtleText
            font.pixelSize: 13
        }

        Rectangle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 16
            radius: 8
            color: root.graphEnabled ? Qt.alpha(root.accent, 0.25) : Theme.popupBorder

            Rectangle {
                x: root.graphEnabled ? 14 : 3
                y: 3
                width: 10
                height: 10
                radius: 5
                color: root.graphEnabled ? Theme.popupAccent : Theme.popupSubtleText

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durationFast
                    }
                }
            }
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
