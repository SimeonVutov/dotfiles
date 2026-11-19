pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking

// Wi-Fi and wired networks: what is available and connected, and scanning,
// connecting and forgetting. The viewer count and the error message are shared
// with Bluetooth in Connectivity.
Singleton {
    id: root

    property int stateRevision: 0

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

    // Called when the last viewer leaves.
    function release() {
        stopWifiScan();
        passwordNetwork = null;
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
        if (!wifiOn || !Connectivity.viewers)
            return;
        Connectivity.error = "";
        scannedWifi = wifiDevices.filter(d => !d.scannerEnabled);
        for (const device of scannedWifi)
            device.scannerEnabled = true;
        wifiScanning = true;
        wifiScanLimit.restart();
    }

    function toggleWifi() {
        Connectivity.error = "";
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function needsPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae, WifiSecurityType.StaticWep].indexOf(network.security) !== -1;
    }

    function connectWifi(network) {
        Connectivity.error = "";
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
        Connectivity.error = "";
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
                if (reason === ConnectionFailReason.NoSecrets && root.needsPassword(modelData) && Connectivity.viewers > 0)
                    root.passwordNetwork = modelData;
                else
                    Connectivity.error = modelData.name + ": " + (reason === ConnectionFailReason.NoSecrets ? "This network needs a configured enterprise profile." : ConnectionFailReason.toString(reason));
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
}
