pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// One visibility-gated cadence for direct /proc and /sys reads.
Singleton {
    id: root

    property real cpuUsage: 0        // percent
    property real memoryUsed: 0      // GiB
    property real memoryTotal: 0     // GiB
    property real temperature: NaN     // celsius

    property real gpuUsage: NaN
    readonly property real memoryPercent: memoryTotal > 0 ? memoryUsed / memoryTotal * 100 : 0
    property var histories: ({
            cpu: [],
            memory: [],
            temperature: [],
            gpu: []
        })
    property var graphWatchers: ({
            cpu: 0,
            memory: 0,
            temperature: 0,
            gpu: 0
        })
    readonly property bool hasGraphs: Object.values(graphWatchers).some(n => n > 0)

    // Each visible graph owns a subscription. Multiple monitors share reads.
    function watchGraph(metric, enabled) {
        const next = Object.assign({}, graphWatchers);
        next[metric] = Math.max(0, next[metric] + (enabled ? 1 : -1));
        graphWatchers = next;
        // Seed newly opened graphs immediately; subsequent reads share the timer.
        if (enabled && next[metric] === 1) {
            if (metric === "memory")
                _sampleMemory();
            if (metric === "temperature")
                _sampleTemperature();
            if (metric === "gpu")
                _sampleGpu();
            const values = {
                cpu: cpuUsage,
                memory: memoryPercent,
                temperature: temperature,
                gpu: gpuUsage
            };
            appendHistory(metric, values[metric]);
        }
        // Don't join data across a period when this metric wasn't observed.
        if (next[metric] === 0) {
            const buffers = Object.assign({}, histories);
            buffers[metric] = [];
            histories = buffers;
        }
    }

    function appendHistory(metric, value) {
        const next = Object.assign({}, histories);
        next[metric] = histories[metric].concat([value]).slice(-Config.hardware.historySamples);
        histories = next;
    }

    property int subscribers: 0

    function subscribe(enabled) {
        subscribers = Math.max(0, subscribers + (enabled ? 1 : -1));
    }

    property real _prevTotal: 0
    property real _prevIdle: 0
    property int _elapsed: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        blockAllReads: true
    }

    FileView {
        id: memInfoFile
        path: "/proc/meminfo"
        blockAllReads: true
    }

    FileView {
        id: thermalFile
        path: Config.hardware.thermalZone
        blockAllReads: true
    }

    FileView {
        id: gpuFile
        // Empty path prevents even an initial read while no GPU graph is visible.
        path: root.graphWatchers.gpu > 0 ? Config.hardware.gpuPath : ""
        blockAllReads: true
        printErrors: false
    }

    function _sampleGpu() {
        gpuFile.reload();
        const value = parseFloat(gpuFile.text());
        gpuUsage = isFinite(value) ? Math.max(0, Math.min(100, value)) : NaN;
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
        for (let i = 1; i < Math.min(parts.length, 9); i++)
            total += parseInt(parts[i], 10) || 0;
        const idle = (parseInt(parts[4], 10) || 0) + (parseInt(parts[5], 10) || 0);

        const hadBaseline = _prevTotal > 0;
        const deltaTotal = total - _prevTotal;
        const deltaIdle = idle - _prevIdle;
        _prevTotal = total;
        _prevIdle = idle;

        if (hadBaseline && deltaTotal > 0)
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
        const milli = parseFloat(thermalFile.text());
        temperature = isFinite(milli) ? milli / 1000 : NaN;
    }

    Timer {
        interval: root.hasGraphs ? Config.hardware.graphInterval : Config.hardware.tickInterval
        repeat: true
        running: root.subscribers > 0 || root.hasGraphs
        onRunningChanged: {
            if (!running) {
                root._prevTotal = 0;
                root._elapsed = 0;
            }
        }
        triggeredOnStart: true
        onTriggered: {
            if (root.graphWatchers.cpu > 0 || (root.subscribers > 0 && root._elapsed % Config.hardware.tickInterval === 0))
                root._sampleCpu();
            if (root.graphWatchers.memory > 0 || (root.subscribers > 0 && root._elapsed % (Config.hardware.tickInterval * Config.hardware.memoryEveryNTicks) === 0))
                root._sampleMemory();
            if (root.graphWatchers.temperature > 0 || (root.subscribers > 0 && root._elapsed % (Config.hardware.tickInterval * Config.hardware.temperatureEveryNTicks) === 0))
                root._sampleTemperature();
            if (root.graphWatchers.gpu > 0)
                root._sampleGpu();
            const values = {
                cpu: root.cpuUsage,
                memory: root.memoryPercent,
                temperature: root.temperature,
                gpu: root.gpuUsage
            };
            for (const metric of Object.keys(values)) {
                if (root.graphWatchers[metric] > 0)
                    root.appendHistory(metric, values[metric]);
            }
            root._elapsed += interval;
        }
    }
}
