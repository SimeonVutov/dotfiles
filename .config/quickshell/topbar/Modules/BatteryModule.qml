import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Ui

BarModule {
    id: root

    // UPower's aggregate device may not identify itself as a laptop battery.
    readonly property var device: {
        const display = UPower.displayDevice;
        if (display && display.ready && display.isPresent && display.isLaptopBattery)
            return display;
        return UPower.devices.values.find(device => device.ready && device.isPresent && device.isLaptopBattery) || null;
    }
    readonly property bool present: !!device && device.ready && device.isPresent && device.isLaptopBattery
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool fullyCharged: !!device && device.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: !!device && !fullyCharged && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)

    readonly property bool critical: present && !charging && percent <= Config.battery.criticalThreshold
    readonly property bool warning: present && !charging && !critical && percent <= Config.battery.warningThreshold

    visible: present
    implicitWidth: present ? pill.implicitWidth : 0

    readonly property color textColor: critical ? Theme.criticalText : (warning ? Theme.warningText : Theme.text)

    readonly property int iconSlotWidth: 22

    Pill {
        id: pill

        background: root.critical ? Theme.criticalBackground : (root.warning ? Theme.warningBackground : Theme.pillBackground)
        backgroundOpacity: root.critical ? root.flashOpacity : Theme.pillOpacity

        Row {
            spacing: 5

            BarText {
                text: root.device ? root.percent + "%" : ""
                color: root.textColor
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
