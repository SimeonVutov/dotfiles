pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Connectivity
import qs.Services
import qs.Popups

BarModule {
    id: root

    moduleViewId: "connections"
    readonly property bool wifiSelected: ModuleViewState.enabled("connections", "wifi")
    readonly property bool bluetoothSelected: ModuleViewState.enabled("connections", "bluetooth")
    readonly property bool showWifi: wifiSelected && !autoHiddenItems.includes("wifi")
    readonly property bool showBluetooth: bluetoothSelected && !autoHiddenItems.includes("bluetooth")
    preferredWidth: pill.paddingH * 2 + (wifiSelected ? wifiSection.expandedWidth : 0) + (bluetoothSelected ? bluetoothSection.expandedWidth : 0) + (wifiSelected && bluetoothSelected ? 9 : 0)

    function widthForCompression(state) {
        const wifi = wifiSelected && !state.hide.includes("wifi");
        const bluetooth = bluetoothSelected && !state.hide.includes("bluetooth");
        if (!wifi && !bluetooth)
            return preferredWidth;
        const iconOnly = state.view === "icons";
        return pill.paddingH * 2 + (wifi ? (iconOnly ? 28 : wifiSection.expandedWidth) : 0) + (bluetooth ? (iconOnly ? 28 : bluetoothSection.expandedWidth) : 0) + (wifi && bluetooth ? 9 : 0);
    }

    function bluetoothLabel(device) {
        const name = device.name || device.deviceName || device.address;
        return device.batteryAvailable ? name + "  " + Icons.bluetoothBattery + " " + Math.round(device.battery * 100) + "%" : name;
    }

    readonly property var bluetoothLabels: bluetoothSelected ? Connectivity.connectedBluetoothDevices.map(device => bluetoothLabel(device)) : []

    Pill {
        id: pill
        paddingH: 8
        animateWidth: false

        Row {
            spacing: root.showWifi && root.showBluetooth ? 4 : 0

            ConnectionPillItem {
                id: wifiSection
                width: root.showWifi ? implicitWidth : 0
                visible: width > 0
                compact: root.autoView === "icons"
                icon: Connectivity.wiredConnected ? Icons.ethernet : Connectivity.wifiOn ? Icons.wifi : Icons.wifiDisabled
                label: Connectivity.wiredConnected ? "Ethernet" : Connectivity.currentWifi ? Connectivity.currentWifi.name : ""
                onClicked: connectionsPopup.showTab("wifi")
            }

            Divider {
                anchors.verticalCenter: parent.verticalCenter
                width: root.showWifi && root.showBluetooth ? 1 : 0
                visible: width > 0
            }

            ConnectionPillItem {
                id: bluetoothSection
                width: root.showBluetooth ? implicitWidth : 0
                visible: width > 0
                compact: root.autoView === "icons"
                icon: !Connectivity.bluetoothOn ? Icons.bluetoothDisabled : Connectivity.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
                rotatingLabels: root.bluetoothLabels
                onClicked: connectionsPopup.showTab("bluetooth")
            }
        }
    }

    PopupHost {
        id: connectionsPopup
        popup: Component {
            ConnectionsPopup {
                anchorItem: pill
            }
        }
    }
}
