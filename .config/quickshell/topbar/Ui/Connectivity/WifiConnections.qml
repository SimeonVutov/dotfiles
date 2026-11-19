pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import Quickshell.Networking
import qs.Common
import qs.Services

DeviceListView {
    id: root

    scanning: WifiService.wifiScanning
    spacing: 4
    emptyText: !WifiService.wifiOn ? "Turn on Wi-Fi to see networks." : WifiService.wifiScanning ? "Looking for nearby networks…" : "Scan to find nearby networks."
    model: WifiService.wifiOn ? WifiService.networks : []

    addTransition: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.durationFast
        }
    }
    removeTransition: Transition {
        NumberAnimation {
            property: "opacity"
            to: 0
            duration: Theme.durationFast
        }
    }
    displacedTransition: Transition {
        NumberAnimation {
            properties: "x,y"
            duration: Theme.durationFast
            easing.type: Theme.easingEmphasized
        }
    }

    delegate: ConnectionRow {
        required property var modelData
        width: ListView.view.width
        title: modelData.name
        active: modelData.connected
        busy: modelData.stateChanging
        subtitle: (modelData.connected ? "Connected" : modelData.known ? "Saved" : WifiSecurityType.toString(modelData.security)) + " · " + Math.round(modelData.signalStrength * 100) + "% · " + modelData.device.name
        action: busy ? "Working…" : modelData.connected ? "Disconnect" : "Connect"
        secondaryAction: modelData.known ? "Forget" : ""
        onActivated: WifiService.connectWifi(modelData)
        onSecondaryActivated: WifiService.forgetWifi(modelData)
    }
}
