pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Bluetooth
import qs.Common
import qs.Services

AdaptiveHeightItem {
    id: root

    property int minimumHeight: 52
    property int scanningHeight: 78
    property int maximumHeight: 196
    readonly property int desiredHeight: list.count > 0 ? Math.min(maximumHeight, list.count * 52 + Math.max(0, list.count - 1) * list.spacing) : Connectivity.bluetoothScanning ? scanningHeight : minimumHeight

    targetHeight: desiredHeight

    ScriptModel {
        id: deviceModel
        comparisonMode: ObjectComparison.Identity
        values: {
            const revision = Connectivity.bluetoothSortRevision;
            if (!Connectivity.bluetoothOn)
                return [];
            return Connectivity.bluetoothDisplayDevices;
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 4
        model: deviceModel
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        delegate: ConnectionRow {
            required property var modelData
            readonly property bool changing: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            readonly property bool targetBusy: Connectivity.bluetoothTarget === modelData.dbusPath || changing
            width: list.width
            title: modelData.name || modelData.deviceName || modelData.address
            subtitle: (modelData.connected ? "Connected" : modelData.paired ? "Saved device" : "Available") + (modelData.trusted ? " · Trusted" : "") + (modelData.batteryAvailable ? " · " + Icons.bluetoothBattery + " " + Math.round(modelData.battery * 100) + "%" : "") + (Bluetooth.adapters.values.length > 1 ? " · " + modelData.adapter.name : "")
            active: modelData.connected
            busy: targetBusy || !modelData.adapter.enabled || modelData.blocked
            action: targetBusy ? "Working…" : modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"
            secondaryAction: modelData.paired ? (modelData.trusted ? "Untrust" : "Trust") : ""
            onActivated: Connectivity.actBluetooth(modelData, modelData.connected ? "disconnect" : modelData.paired ? "connect" : "pair")
            onSecondaryActivated: modelData.trusted ? Connectivity.forgetBluetooth(modelData) : Connectivity.actBluetooth(modelData, "trust")
        }
    }
    BarText {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: list.count === 0
        text: !Connectivity.bluetoothOn ? "Turn on Bluetooth to see devices." : Connectivity.bluetoothScanning ? "Looking for nearby devices…" : "Scan with your device in pairing mode."
        color: Theme.popupSubtleText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: 13
    }
}
