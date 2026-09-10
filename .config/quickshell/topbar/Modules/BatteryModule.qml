import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.Common
import qs.Ui

// Battery, straight off UPower — no polling. Hides itself entirely on machines
// without a battery, same as waybar did.
BarModule {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool present: !!device && device.ready && device.isPresent && device.isLaptopBattery
    readonly property int percent: device ? Math.round(device.percentage * 100) : 0
    readonly property bool fullyCharged: !!device && device.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: !!device && !fullyCharged && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)

    readonly property bool critical: present && !charging && percent <= Config.battery.criticalThreshold
    readonly property bool warning: present && !charging && !critical && percent <= Config.battery.warningThreshold

    visible: present
    implicitWidth: present ? pill.implicitWidth : 0

    Pill {
        id: pill

        background: root.critical ? Theme.criticalBackground : (root.warning ? Theme.warningBackground : Theme.pillBackground)

        Row {
            spacing: 5

            BarText {
                text: root.device ? root.percent + "%" : ""
            }

            Item {
                width: 22
                height: parent.height

                BarText {
                    anchors.centerIn: parent
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

    // Waybar blinked the pill when the battery was critical and discharging.
    SequentialAnimation {
        running: root.critical
        loops: Animation.Infinite
        alwaysRunToEnd: true

        NumberAnimation {
            target: pill
            property: "opacity"
            to: 0.45
            duration: 500
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: pill
            property: "opacity"
            to: Theme.pillOpacity
            duration: 500
            easing.type: Easing.InOutQuad
        }
    }
}
