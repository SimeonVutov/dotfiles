pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Common
import qs.Ui
import qs.Services

PopupPanel {
    id: root

    property bool subscribed: false
    property string selectedTab: "wifi"

    panelWidth: 380
    animateHeight: true
    smoothAnchorMovement: true
    contentPadding: 14
    rowSpacing: 8
    overlayActive: !!Connectivity.passwordNetwork || !!Connectivity.bluetoothPrompt
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

    function syncSubscription() {
        if (subscribed === open)
            return;
        subscribed = open;
        Connectivity.subscribe(open);
    }
    onOpenChanged: syncSubscription()
    onOverlayDismissed: {
        Connectivity.passwordNetwork = null;
        if (Connectivity.bluetoothPrompt)
            Connectivity.cancelBluetooth();
    }
    Component.onCompleted: syncSubscription()
    Component.onDestruction: if (subscribed)
        Connectivity.subscribe(false)

    ConnectionTabs {
        Layout.fillWidth: true
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
                glyph: Connectivity.wifiOn ? Icons.wifi : Icons.wifiDisabled
                subtitle: Connectivity.wifiStatus
                powered: Connectivity.wifiOn
                enabled: Connectivity.wifiDevices.length > 0 && Networking.wifiHardwareEnabled
                onClicked: Connectivity.toggleWifi()
            }

            ConnectionListHeader {
                width: parent.width
                title: "Networks"
                scanning: Connectivity.wifiScanning
                scanEnabled: Connectivity.wifiOn
                onScanClicked: Connectivity.scanWifi()
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
                glyph: !Connectivity.bluetoothOn ? Icons.bluetoothDisabled : Connectivity.connectedCount > 0 ? Icons.bluetoothConnected : Icons.bluetooth
                subtitle: Connectivity.bluetoothStatus
                powered: Connectivity.bluetoothOn
                enabled: !!Connectivity.adapter && Connectivity.adapter.state !== BluetoothAdapterState.Blocked && Connectivity.adapter.state !== BluetoothAdapterState.Enabling && Connectivity.adapter.state !== BluetoothAdapterState.Disabling
                onClicked: Connectivity.toggleBluetooth()
            }

            ConnectionListHeader {
                width: parent.width
                title: "Devices"
                scanning: Connectivity.bluetoothScanning
                scanEnabled: Connectivity.bluetoothOn
                onScanClicked: Connectivity.scanBluetooth()
            }

            BluetoothConnections {
                width: parent.width
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        Layout.preferredHeight: text === "" ? 0 : 24
        visible: Layout.preferredHeight > 0
        text: Connectivity.error
        color: Theme.graphTemperature
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
}
