import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Common
import qs.Ui

// Network and bluetooth share one pill, as they did in waybar's group. Both
// read from Quickshell's DBus-backed services, so neither one polls.
BarModule {
    id: root

    // ── Network ────────────────────────────────────────────────
    readonly property var devices: Networking.devices.values
    readonly property var wifiDevice: devices.find(d => d.type === 1 && d.connected) ?? null
    readonly property var ethernetDevice: devices.find(d => d.type === 2 && d.connected) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    readonly property string networkText: {
        if (wifiDevice)
            return Icons.wifi + "   " + Math.round((wifiNetwork ? wifiNetwork.signalStrength : 0) * 100) + "%";
        if (ethernetDevice)
            return Icons.ethernet + "  " + ethernetDevice.name;
        return "Disconnected";
    }

    // ── Bluetooth ──────────────────────────────────────────────
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var deviceWithBattery: connectedDevices.find(d => d.batteryAvailable) ?? null

    readonly property string bluetoothText: {
        if (!adapter || !adapter.enabled)
            return Icons.bluetoothDisabled;
        if (deviceWithBattery)
            return Icons.bluetoothBattery + " " + deviceWithBattery.deviceName + " " + Math.round(deviceWithBattery.battery * 100) + "%";
        if (connectedDevices.length > 0)
            return Icons.bluetoothConnected + "  " + connectedDevices.length;
        return Icons.bluetooth;
    }

    Pill {
        Row {
            spacing: Theme.groupSpacing

            BarText {
                text: root.networkText

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(Config.network.onClick)
                }
            }

            BarText {
                // #network carried an explicit 15px; #bluetooth kept the 14px base.
                font.pixelSize: Theme.fontSizeSmall
                text: root.bluetoothText

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(Config.bluetooth.onClick)
                }
            }
        }
    }
}
