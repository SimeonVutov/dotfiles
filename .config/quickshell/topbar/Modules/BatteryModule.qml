import QtQuick
import qs.Common
import qs.Ui
import qs.Services

BarModule {
    id: root

    moduleViewId: "battery"
    readonly property string selectedView: ModuleViewState.selection("battery")
    preferredWidth: present ? pill.paddingH * 2 + iconSlotWidth + (selectedView === "full" ? percentText.implicitWidth : 0) : 0

    readonly property bool present: Battery.present
    readonly property int percent: Battery.percent
    readonly property bool fullyCharged: Battery.fullyCharged
    readonly property bool charging: Battery.charging

    readonly property bool critical: present && !charging && percent <= Config.battery.criticalThreshold
    readonly property bool warning: present && !charging && !critical && percent <= Config.battery.warningThreshold

    visible: present
    implicitWidth: present ? pill.implicitWidth : 0

    readonly property color textColor: critical ? Theme.criticalText : (warning ? Theme.warningText : Theme.text)

    readonly property int iconSlotWidth: 22

    Pill {
        id: pill
        animateWidth: false

        background: root.critical ? Theme.criticalBackground : (root.warning ? Theme.warningBackground : Theme.pillBackground)
        backgroundOpacity: root.critical ? root.flashOpacity : Theme.pillOpacity

        Row {
            spacing: 0

            BarText {
                id: percentText
                rightPadding: 5
                text: root.present ? root.percent + "%" : ""
                color: root.textColor
                clip: true
                width: root.selectedView === "icon" ? 0 : implicitWidth
                visible: width > 0

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Theme.easingEmphasized
                    }
                }
            }

            Item {
                width: root.iconSlotWidth
                height: parent.height

                BarText {
                    anchors.centerIn: parent
                    color: root.textColor
                    text: {
                        if (root.fullyCharged)
                            return Icons.batteryLevels[Icons.batteryLevels.length - 1];
                        if (root.charging)
                            return Icons.batteryCharging;
                        const index = Math.max(0, Math.min(Icons.batteryLevels.length - 1, Math.floor(root.percent / 100 * Icons.batteryLevels.length)));
                        return Icons.batteryLevels[index];
                    }
                }
            }
        }
    }

    // Animate separately to preserve the backgroundOpacity binding.
    property real flashOpacity: Theme.pillOpacity

    readonly property int flashHalfCycle: 500
    readonly property real flashLowOpacity: 0.45

    SequentialAnimation {
        running: root.critical
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            target: root
            property: "flashOpacity"
            to: root.flashLowOpacity
            duration: root.flashHalfCycle
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: root
            property: "flashOpacity"
            to: Theme.pillOpacity
            duration: root.flashHalfCycle
            easing.type: Easing.InOutQuad
        }
    }
}
