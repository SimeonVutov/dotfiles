pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root

    readonly property string capacity0: battery0.text().trim()
    readonly property string capacity1: battery1.text().trim()
    readonly property int activeIndex: capacity0 !== "" ? 0 : capacity1 !== "" ? 1 : -1
    readonly property string capacityText: activeIndex === 0 ? capacity0 : activeIndex === 1 ? capacity1 : ""
    readonly property real capacity: Number(capacityText)
    readonly property bool present: capacityText !== "" && isFinite(capacity) && capacity >= 0 && capacity <= 100
    readonly property int percent: present ? Math.round(capacity) : 0
    readonly property string status: statusFile.text().trim()
    readonly property bool fullyCharged: status === "Full"
    readonly property bool charging: !fullyCharged && status === "Charging"

    function refresh() {
        battery0.reload();
        battery1.reload();
        if (activeIndex >= 0)
            statusFile.reload();
    }

    FileView {
        id: battery0
        path: Config.battery.paths[0] + "/capacity"
        printErrors: false
    }

    FileView {
        id: battery1
        path: Config.battery.paths[1] + "/capacity"
        printErrors: false
    }

    FileView {
        id: statusFile
        path: root.activeIndex >= 0 ? Config.battery.paths[root.activeIndex] + "/status" : ""
        printErrors: false
    }

    Timer {
        interval: Config.battery.refreshInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
