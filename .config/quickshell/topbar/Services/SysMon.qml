pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// CPU / memory / temperature, read straight out of /proc and /sys.
//
// This is the only part of the bar that has to poll, so it does so as cheaply
// as possible: one timer for all three values instead of three, direct file
// reads instead of forking a shell, and nothing runs at all unless a module is
// actually on screen asking for the numbers.
Singleton {
    id: root

    property real cpuUsage: 0        // percent
    property real memoryUsed: 0      // GiB
    property real memoryTotal: 0     // GiB
    property real temperature: 0     // celsius

    property int subscribers: 0

    function subscribe(enabled) {
        subscribers = Math.max(0, subscribers + (enabled ? 1 : -1));
    }

    property real _prevTotal: 0
    property real _prevIdle: 0
    property int _tick: 0

    FileView {
        id: statFile
        path: "/proc/stat"
    }

    FileView {
        id: memInfoFile
        path: "/proc/meminfo"
    }

    FileView {
        id: thermalFile
        path: Config.hardware.thermalZone
    }

    function _sampleCpu() {
        statFile.reload();
        const text = statFile.text();
        if (!text)
            return;
        // "cpu  user nice system idle iowait irq softirq steal ..."
        const line = text.substring(0, text.indexOf("\n"));
        const parts = line.trim().split(/\s+/);
        if (parts.length < 8)
            return;

        let total = 0;
        for (let i = 1; i < parts.length; i++)
            total += parseInt(parts[i], 10) || 0;
        const idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);

        const deltaTotal = total - _prevTotal;
        const deltaIdle = idle - _prevIdle;
        _prevTotal = total;
        _prevIdle = idle;

        if (deltaTotal > 0)
            cpuUsage = Math.max(0, Math.min(100, (deltaTotal - deltaIdle) / deltaTotal * 100));
    }

    function _sampleMemory() {
        memInfoFile.reload();
        const text = memInfoFile.text();
        if (!text)
            return;
        const totalMatch = text.match(/MemTotal:\s+(\d+) kB/);
        const availableMatch = text.match(/MemAvailable:\s+(\d+) kB/);
        if (!totalMatch || !availableMatch)
            return;
        const totalKb = parseInt(totalMatch[1], 10);
        const availableKb = parseInt(availableMatch[1], 10);
        memoryTotal = totalKb / 1048576;
        memoryUsed = (totalKb - availableKb) / 1048576;
    }

    function _sampleTemperature() {
        thermalFile.reload();
        const text = thermalFile.text();
        if (!text)
            return;
        const milli = parseInt(text.trim(), 10);
        if (!isNaN(milli))
            temperature = milli / 1000;
    }

    Timer {
        interval: Config.hardware.tickInterval
        repeat: true
        running: root.subscribers > 0
        triggeredOnStart: true
        onTriggered: {
            root._sampleCpu();
            if (root._tick % Config.hardware.memoryEveryNTicks === 0)
                root._sampleMemory();
            if (root._tick % Config.hardware.temperatureEveryNTicks === 0)
                root._sampleTemperature();
            root._tick++;
        }
    }
}
