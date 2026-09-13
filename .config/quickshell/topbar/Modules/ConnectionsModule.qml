import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Connectivity
import qs.Services
import qs.Popups

BarModule {
    id: root

    function bluetoothLabel(device) {
        const name = device.name || device.deviceName || device.address;
        return device.batteryAvailable ? name + "  " + Icons.bluetoothBattery + " " + Math.round(device.battery * 100) + "%" : name;
    }

    readonly property var bluetoothLabels: Connectivity.connectedBluetoothDevices.map(device => bluetoothLabel(device))
    readonly property bool wifiHasLabel: Connectivity.wiredConnected || !!Connectivity.currentWifi
    readonly property bool bluetoothHasLabel: bluetoothLabels.length > 0
    readonly property int sectionWidth: Math.max(wifiSection.implicitWidth, bluetoothSection.implicitWidth)

    Pill {
        id: pill
        paddingH: 8
        animateWidth: false

        Row {
            spacing: 4

            ConnectionPillItem {
                id: wifiSection
                width: root.wifiHasLabel && root.bluetoothHasLabel ? root.sectionWidth : implicitWidth
                icon: Connectivity.wiredConnected ? Icons.ethernet : Connectivity.wifiOn ? Icons.wifi : Icons.wifiDisabled
                label: Connectivity.wiredConnected ? "Ethernet" : Connectivity.currentWifi ? Connectivity.currentWifi.name : ""
                onClicked: connectionsPopup.showTab("wifi")
            }

            Divider {
                anchors.verticalCenter: parent.verticalCenter
            }

            ConnectionPillItem {
                id: bluetoothSection
                width: root.wifiHasLabel && root.bluetoothHasLabel ? root.sectionWidth : implicitWidth
                icon: !Connectivity.bluetoothOn ? Icons.bluetoothDisabled : Connectivity.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
                rotatingLabels: root.bluetoothLabels
                onClicked: connectionsPopup.showTab("bluetooth")
            }
        }
    }

    ConnectionsPopup {
        id: connectionsPopup
        anchorItem: pill
    }
}
