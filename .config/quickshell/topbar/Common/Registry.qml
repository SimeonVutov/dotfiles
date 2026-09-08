pragma Singleton

import QtQuick
import Quickshell

// Maps a module id to the file that implements it.
//
// Adding a module: drop a file in Modules/, add one line here, then put its id
// into one of the arrays in Config.qml. Removing one: take the id back out of
// Config.qml. Nothing else in the bar refers to modules by name.
Singleton {
    id: root

    readonly property var modules: ({
            clock: "ClockModule.qml",
            media: "MediaModule.qml",
            workspaces: "WorkspacesModule.qml",
            hardware: "HardwareModule.qml",
            volume: "VolumeModule.qml",
            connections: "ConnectionsModule.qml",
            battery: "BatteryModule.qml",
            power: "PowerModule.qml"
        })

    function urlFor(id) {
        const file = modules[id];
        if (!file) {
            console.warn("[topbar] unknown module id:", id);
            return "";
        }
        return Qt.resolvedUrl("../Modules/" + file);
    }
}
