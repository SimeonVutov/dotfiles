import QtQuick
import qs.Common
import qs.Services

Rectangle {
    id: root
    required property string metric
    required property string label
    required property string valueLabel
    required property color accent
    property real maximum: 100
    property bool consuming: false
    readonly property bool graphEnabled: !!Config.hardwareGraphs[metric]
    readonly property bool watching: consuming && graphEnabled
    property bool subscribed: false
    implicitHeight: graphEnabled ? 92 : 44
    radius: 12
    color: Theme.popupSurface
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
        x: 14
        y: 12
        width: parent.width - 28
        height: 20
        Rectangle {
            width: 5
            height: 5
            radius: 3
            anchors.verticalCenter: parent.verticalCenter
            color: root.graphEnabled ? root.accent : Theme.popupSubtleText
        }
        BarText {
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.graphEnabled ? Theme.popupText : Theme.popupSubtleText
            font.pixelSize: 13
        }
        BarText {
            anchors.right: toggle.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.graphEnabled ? root.valueLabel : "Hidden"
            color: root.graphEnabled ? Theme.popupText : Theme.popupSubtleText
            font.pixelSize: 14
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
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: Config.toggleHardwareGraph(root.metric)
        }
    }
    StripChart {
        x: 14
        y: 40
        width: parent.width - 28
        height: Math.max(0, parent.height - y - 10)
        visible: root.graphEnabled
        active: root.watching
        samples: SysMon.histories[root.metric]
        accent: root.accent
        maximum: root.maximum
    }
}
