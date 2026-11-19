pragma Singleton

import QtQuick
import Quickshell

// What the Wi-Fi and Bluetooth services share: how many views are showing them
// (they scan only while someone looks), and the last error to show.
Singleton {
    property int viewers: 0
    property string error: ""

    function subscribe(enabled) {
        viewers = Math.max(0, viewers + (enabled ? 1 : -1));
        if (viewers === 0) {
            WifiService.release();
            BluetoothService.release();
        }
    }
}
