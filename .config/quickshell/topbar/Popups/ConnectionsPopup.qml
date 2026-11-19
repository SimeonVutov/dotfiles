pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Common
import qs.Ui
import qs.Ui.Connectivity
import qs.Services

PopupPanel {
    id: root

    property string selectedTab: "wifi"

    panelWidth: 380
    animateHeight: true
    smoothAnchorMovement: true
    contentPadding: 14
    rowSpacing: 8
    overlayActive: !!WifiService.passwordNetwork || !!BluetoothService.bluetoothPrompt
    overlayPage: Component {
        ConnectionPrompt {
            active: root.open && root.overlayActive
        }
    }

    function showTab(tab) {
        const sameOpenTab = open && selectedTab === tab;
        selectedTab = tab;
        open = !sameOpenTab;
    }

    onOverlayDismissed: {
        WifiService.passwordNetwork = null;
        if (BluetoothService.bluetoothPrompt)
            BluetoothService.cancelBluetooth();
    }

    Subscriber {
        active: root.open
        onToggled: enabled => Connectivity.subscribe(enabled)
    }

    TabSwitcher {
        Layout.fillWidth: true
        tabs: [
            {
                value: "wifi",
                label: "Wi-Fi",
                icon: Icons.wifi
            },
            {
                value: "bluetooth",
                label: "Bluetooth",
                icon: Icons.bluetooth
            }
        ]
        currentTab: root.selectedTab
        onSelected: tab => root.selectedTab = tab
    }

    Item {
        id: pages
        Layout.fillWidth: true
        Layout.preferredHeight: root.selectedTab === "wifi" ? wifiPage.implicitHeight : bluetoothPage.implicitHeight
        clip: true

        Column {
            id: wifiPage
            width: parent.width
            spacing: 8
            visible: root.selectedTab === "wifi"

            RadioToggle {
                width: parent.width
                heading: "Wi-Fi"
                glyph: WifiService.wifiOn ? Icons.wifi : Icons.wifiDisabled
                subtitle: WifiService.wifiStatus
                powered: WifiService.wifiOn
                enabled: WifiService.wifiDevices.length > 0 && Networking.wifiHardwareEnabled
                onClicked: WifiService.toggleWifi()
            }

            ConnectionListHeader {
                width: parent.width
                title: "Networks"
                scanning: WifiService.wifiScanning
                scanEnabled: WifiService.wifiOn
                onScanClicked: WifiService.scanWifi()
            }

            WifiConnections {
                width: parent.width
            }
        }

        Column {
            id: bluetoothPage
            width: parent.width
            spacing: 8
            visible: root.selectedTab === "bluetooth"

            RadioToggle {
                width: parent.width
                heading: "Bluetooth"
                glyph: !BluetoothService.bluetoothOn ? Icons.bluetoothDisabled : BluetoothService.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
                subtitle: BluetoothService.bluetoothStatus
                powered: BluetoothService.bluetoothOn
                enabled: !!BluetoothService.adapter && BluetoothService.adapter.state !== BluetoothAdapterState.Blocked && BluetoothService.adapter.state !== BluetoothAdapterState.Enabling && BluetoothService.adapter.state !== BluetoothAdapterState.Disabling
                onClicked: BluetoothService.toggleBluetooth()
            }

            ConnectionListHeader {
                width: parent.width
                title: "Devices"
                scanning: BluetoothService.bluetoothScanning
                scanEnabled: BluetoothService.bluetoothOn
                onScanClicked: BluetoothService.scanBluetooth()
            }

            BluetoothConnections {
                width: parent.width
            }
        }
    }

    PopupPanel.ErrorBanner {
        text: Connectivity.error
    }
}
