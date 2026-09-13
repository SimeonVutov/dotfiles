pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import Quickshell
import Quickshell.Bluetooth
import qs.Common
import qs.Services

DeviceListView {
    id: root

    scanning: Connectivity.bluetoothScanning
    spacing: 4
    emptyText: !Connectivity.bluetoothOn ? "Turn on Bluetooth to see devices." : Connectivity.bluetoothScanning ? "Looking for nearby devices…" : "Scan with your device in pairing mode."

    ScriptModel {
        id: deviceModel
        comparisonMode: ObjectComparison.Identity
        values: {
            // Track reordering even when device identities stay unchanged.
            const revision = Connectivity.bluetoothSortRevision;
            if (!Connectivity.bluetoothOn)
                return [];
            return Connectivity.bluetoothDisplayDevices;
        }
    }

    model: deviceModel
    delegate: ConnectionRow {
        required property var modelData
        readonly property bool changing: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
        readonly property bool targetBusy: Connectivity.bluetoothTarget === modelData.dbusPath || changing
        width: ListView.view.width
        title: modelData.name || modelData.deviceName || modelData.address
        subtitle: (modelData.connected ? "Connected" : modelData.paired ? "Saved device" : "Available") + (modelData.trusted ? " · Trusted" : "") + (modelData.batteryAvailable ? " · " + Icons.bluetoothBattery + " " + Math.round(modelData.battery * 100) + "%" : "") + (Bluetooth.adapters.values.length > 1 ? " · " + modelData.adapter.name : "")
        active: modelData.connected
        busy: targetBusy || !modelData.adapter.enabled || modelData.blocked
        action: targetBusy ? "Working…" : modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
        secondaryAction: modelData.paired ? "Unpair" : ""
        onActivated: Connectivity.actBluetooth(modelData, modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair")
        onSecondaryActivated: Connectivity.forgetBluetooth(modelData)
    }
}
