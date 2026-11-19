pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth: the adapter and its devices, scanning, and connecting and pairing
// (pairing runs through a helper process that can ask for a confirmation). The
// viewer count and the error message are shared with Wi-Fi in Connectivity.
Singleton {
    id: root

    property int stateRevision: 0

    readonly property var bluetoothAdapters: Bluetooth.adapters.values
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var bluetoothDevices: Bluetooth.devices.values
    readonly property var connectedBluetoothDevices: {
        const revision = stateRevision;
        return bluetoothDevices.filter(d => d.connected);
    }
    readonly property int connectedCount: connectedBluetoothDevices.length
    readonly property bool bluetoothOn: !!adapter && adapter.enabled
    readonly property string bluetoothStatus: !adapter ? "No adapter" : adapter.state === BluetoothAdapterState.Blocked ? "Hardware blocked" : !bluetoothOn ? "Off" : connectedCount > 0 ? connectedCount + " connected" : "Not connected"
    property int bluetoothSortRevision: 0
    property var bluetoothDisplayDevices: []
    property bool bluetoothScanning: false
    property var scannedAdapter: null
    property var bluetoothPrompt: null
    property string bluetoothTarget: ""
    property string bluetoothName: ""
    readonly property bool bluetoothBusy: bluetoothAction.running
    property bool actionResult: false

    // Called when the last viewer leaves.
    function release() {
        stopBluetoothScan();
        if (bluetoothPrompt || (bluetoothBusy && bluetoothAction.command[3] === "pair"))
            cancelBluetooth();
    }

    function stopBluetoothScan() {
        bluetoothScanLimit.stop();
        if (scannedAdapter && bluetoothAdapters.indexOf(scannedAdapter) !== -1)
            scannedAdapter.discovering = false;
        scannedAdapter = null;
        bluetoothScanning = false;
    }

    function scanBluetooth() {
        if (bluetoothScanning) {
            stopBluetoothScan();
            return;
        }
        if (!bluetoothOn || !Connectivity.viewers)
            return;
        Connectivity.error = "";
        scannedAdapter = adapter.discovering ? null : adapter;
        if (scannedAdapter)
            scannedAdapter.discovering = true;
        bluetoothScanning = true;
        bluetoothScanLimit.restart();
    }

    function toggleBluetooth() {
        Connectivity.error = "";
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    function scheduleBluetoothSort() {
        bluetoothSortDelay.restart();
    }

    function refreshBluetoothDisplay() {
        const devices = [...bluetoothDevices];
        devices.sort((a, b) => {
            const rankA = a.connected ? 0 : a.paired ? 1 : 2;
            const rankB = b.connected ? 0 : b.paired ? 1 : 2;
            if (rankA !== rankB)
                return rankA - rankB;
            const nameA = a.name || a.deviceName || a.address || "";
            const nameB = b.name || b.deviceName || b.address || "";
            return nameA.localeCompare(nameB);
        });
        bluetoothDisplayDevices = devices;
        bluetoothSortRevision++;
    }

    function actBluetooth(device, action) {
        if (!device || bluetoothDevices.indexOf(device) === -1 || bluetoothBusy || device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting)
            return;
        if (device.blocked) {
            Connectivity.error = "This device is blocked in Bluetooth settings.";
            return;
        }
        Connectivity.error = "";
        bluetoothPrompt = null;
        if (action === "connect") {
            device.connect();
            return;
        }
        if (action === "disconnect") {
            device.disconnect();
            return;
        }
        if (action !== "pair")
            return;
        bluetoothTarget = device.dbusPath;
        bluetoothName = device.name || device.deviceName || device.address;
        actionResult = false;
        bluetoothAction.command = ["python3", Quickshell.shellPath("Services/bluetooth-action.py"), device.dbusPath, action];
        bluetoothAction.running = true;
    }

    function forgetBluetooth(device) {
        if (!device || bluetoothDevices.indexOf(device) === -1 || bluetoothBusy || !device.paired || device.pairing || device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting)
            return;
        Connectivity.error = "";
        device.forget();
    }

    function cancelBluetooth() {
        if (bluetoothBusy)
            bluetoothAction.write(JSON.stringify({
                cancel: true
            }) + "\n");
        bluetoothPrompt = null;
    }

    function answerBluetooth(value) {
        if (bluetoothBusy)
            bluetoothAction.write(JSON.stringify({
                value: value
            }) + "\n");
        bluetoothPrompt = null;
    }

    onAdapterChanged: stopBluetoothScan()

    onBluetoothOnChanged: {
        if (!bluetoothOn)
            stopBluetoothScan();
        scheduleBluetoothSort();
    }

    onBluetoothDevicesChanged: scheduleBluetoothSort()

    Timer {
        id: bluetoothScanLimit
        interval: 20000
        onTriggered: root.stopBluetoothScan()
    }

    Timer {
        id: bluetoothSortDelay
        interval: 180
        onTriggered: root.refreshBluetoothDisplay()
    }

    Component.onCompleted: refreshBluetoothDisplay()

    Instantiator {
        model: root.bluetoothDevices
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onConnectedChanged() {
                root.stateRevision++;
                root.scheduleBluetoothSort();
            }
            function onPairedChanged() {
                root.stateRevision++;
                root.scheduleBluetoothSort();
            }
        }
    }

    Process {
        id: bluetoothAction
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.event === "prompt")
                        root.bluetoothPrompt = message;
                    else if (message.event === "clear")
                        root.bluetoothPrompt = null;
                    else if (message.event === "error" || message.event === "done") {
                        root.actionResult = true;
                        root.bluetoothPrompt = null;
                        if (message.event === "error")
                            Connectivity.error = message.message;
                    }
                } catch (_) {
                    Connectivity.error = "Invalid response from Bluetooth helper.";
                }
            }
        }
        onExited: code => {
            root.bluetoothPrompt = null;
            root.bluetoothTarget = "";
            if (!root.actionResult || code !== 0)
                Connectivity.error = "Bluetooth action failed. Check BlueZ and python-gobject are available.";
        }
    }
}
