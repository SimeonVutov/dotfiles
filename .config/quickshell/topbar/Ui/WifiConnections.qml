pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Networking
import qs.Common
import qs.Services

AdaptiveHeightItem {
    id: root

    property int minimumHeight: 52
    property int scanningHeight: 78
    property int maximumHeight: 196
    readonly property int desiredHeight: list.count > 0 ? Math.min(maximumHeight, list.count * 52 + Math.max(0, list.count - 1) * list.spacing) : Connectivity.wifiScanning ? scanningHeight : minimumHeight

    targetHeight: desiredHeight

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 4
        model: Connectivity.wifiOn ? Connectivity.networks : []
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.durationFast
            }
        }
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.durationFast
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }
        delegate: ConnectionRow {
            required property var modelData
            width: list.width
            title: modelData.name
            active: modelData.connected
            busy: modelData.stateChanging
            subtitle: (modelData.connected ? "Connected" : modelData.known ? "Saved" : WifiSecurityType.toString(modelData.security)) + " · " + Math.round(modelData.signalStrength * 100) + "% · " + modelData.device.name
            action: busy ? "Working…" : modelData.connected ? "Disconnect" : "Connect"
            onActivated: Connectivity.connectWifi(modelData)
        }
    }
    BarText {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: list.count === 0
        text: !Connectivity.wifiOn ? "Turn on Wi-Fi to see networks." : Connectivity.wifiScanning ? "Looking for nearby networks…" : "Scan to find nearby networks."
        color: Theme.popupSubtleText
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.pixelSize: 13
    }
}
