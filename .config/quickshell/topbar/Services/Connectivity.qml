pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth

Singleton {
    id: root

    property int stateRevision: 0
    property string error: ""
    property int viewers: 0

    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    readonly property var networks: wifiDevices.reduce((all, d) => all.concat(d.networks.values), []).filter(n => n.name !== "")
    readonly property var currentWifi: {
        const revision = stateRevision;
        return networks.find(n => n.connected) ?? null;
    }
    readonly property bool wifiOn: Networking.wifiEnabled && Networking.wifiHardwareEnabled
    readonly property bool wiredConnected: {
        const revision = stateRevision;
        return wiredDevices.some(d => d.connected);
    }
    readonly property string wifiStatus: !wifiDevices.length ? "No adapter" : !Networking.wifiHardwareEnabled ? "Hardware blocked" : !wifiOn ? "Off" : currentWifi ? currentWifi.name : "Not connected"
    property bool wifiScanning: false
    property var scannedWifi: []
    property var passwordNetwork: null

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

    function subscribe(enabled) {
        viewers = Math.max(0, viewers + (enabled ? 1 : -1));
        if (viewers === 0) {
            stopWifiScan();
            stopBluetoothScan();
            passwordNetwork = null;
            if (bluetoothPrompt || (bluetoothBusy && bluetoothAction.command[3] === "pair"))
                cancelBluetooth();
        }
    }

    function stopWifiScan() {
        wifiScanLimit.stop();
        for (const device of scannedWifi) {
            if (wifiDevices.indexOf(device) !== -1)
                device.scannerEnabled = false;
        }
        scannedWifi = [];
        wifiScanning = false;
    }

    function scanWifi() {
        if (wifiScanning) {
            stopWifiScan();
            return;
        }
        if (!wifiOn || !viewers)
            return;
        error = "";
        scannedWifi = wifiDevices.filter(d => !d.scannerEnabled);
        for (const device of scannedWifi)
            device.scannerEnabled = true;
        wifiScanning = true;
        wifiScanLimit.restart();
    }

    function toggleWifi() {
        error = "";
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function needsPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae, WifiSecurityType.StaticWep].indexOf(network.security) !== -1;
    }

    function connectWifi(network) {
        error = "";
        if (!network || networks.indexOf(network) === -1 || network.stateChanging)
            return;
        if (network.connected) {
            network.disconnect();
            return;
        }
        if (!network.known && needsPassword(network))
            passwordNetwork = network;
        else
            network.connect();
    }

    function submitPassword(password) {
        const network = passwordNetwork;
        passwordNetwork = null;
        // NetworkManager owns persistent credentials; never log this value.
        if (network && networks.indexOf(network) !== -1 && !network.stateChanging)
            network.connectWithPsk(password);
    }

    function forgetWifi(network) {
        if (!network || networks.indexOf(network) === -1 || !network.known || network.stateChanging)
            return;
        error = "";
        if (passwordNetwork === network)
            passwordNetwork = null;
        // NetworkManager deletes the saved profile and handles deactivation.
        network.forget();
    }

    onWifiOnChanged: if (!wifiOn) {
        stopWifiScan();
        passwordNetwork = null;
    }

    onNetworksChanged: if (passwordNetwork && networks.indexOf(passwordNetwork) === -1)
        passwordNetwork = null

    Timer {
        id: wifiScanLimit
        interval: 20000
        onTriggered: root.stopWifiScan()
    }

    Instantiator {
        model: root.networks
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onConnectedChanged() {
                root.stateRevision++;
            }
            function onKnownChanged() {
                root.stateRevision++;
            }
            function onStateChangingChanged() {
                root.stateRevision++;
            }
            function onConnectionFailed(reason) {
                if (reason === ConnectionFailReason.NoSecrets && root.needsPassword(modelData) && root.viewers > 0)
                    root.passwordNetwork = modelData;
                else
                    root.error = modelData.name + ": " + (reason === ConnectionFailReason.NoSecrets ? "This network needs a configured enterprise profile." : ConnectionFailReason.toString(reason));
            }
        }
    }

    Instantiator {
        model: Networking.devices.values
        delegate: Connections {
            required property var modelData
            target: modelData
            ignoreUnknownSignals: true
            function onConnectedChanged() {
                root.stateRevision++;
            }
            function onStateChanged() {
                root.stateRevision++;
            }
        }
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
        if (!bluetoothOn || !viewers)
            return;
        error = "";
        scannedAdapter = adapter.discovering ? null : adapter;
        if (scannedAdapter)
            scannedAdapter.discovering = true;
        bluetoothScanning = true;
        bluetoothScanLimit.restart();
    }

    function toggleBluetooth() {
        error = "";
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
            error = "This device is blocked in Bluetooth settings.";
            return;
        }
        error = "";
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
        error = "";
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
                            root.error = message.message;
                    }
                } catch (_) {
                    root.error = "Invalid response from Bluetooth helper.";
                }
            }
        }
        onExited: code => {
            root.bluetoothPrompt = null;
            root.bluetoothTarget = "";
            if (!root.actionResult || code !== 0)
                root.error = "Bluetooth action failed. Check BlueZ and python-gobject are available.";
        }
    }
}
