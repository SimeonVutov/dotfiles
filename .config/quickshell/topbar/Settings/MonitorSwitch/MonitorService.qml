import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import "Layout.js" as Layout

Item {
    id: root

    property bool active: false
    property var monitors: []
    property string revision: ""
    property string mode: "extend"
    property string selected: ""
    property string error: ""
    property bool dirty: false
    property bool previewing: false
    property int secondsLeft: 0
    property int previewSeconds: 1
    property double deadline: 0
    property bool receivedResult: false
    readonly property bool busy: inspect.running || transaction.running
    readonly property bool applying: transaction.running
    readonly property var selectedMonitor: monitors.find(m => m.name === selected) || null
    readonly property string helper: Qt.resolvedUrl("monitor_control.py").toString().replace(/^file:\/\//, "")

    function refresh(preserveError) {
        if (busy)
            return;
        if (!preserveError)
            error = "";
        inspect.running = true;
    }

    function chooseMode(value) {
        if (busy)
            return;
        mode = value;
        monitors = Layout.mode(monitors, value);
        dirty = true;
    }

    function move(name, x, y, threshold) {
        if (busy || mode === "duplicate")
            return;
        monitors = Layout.move(monitors, name, x, y, threshold);
        dirty = true;
    }

    function toggleDisplay(name) {
        if (busy || mode !== "custom" || monitors.length < 3)
            return;
        const next = Layout.copy(monitors), target = next.find(m => m.name === name);
        if (target.enabled && next.filter(m => m.enabled).length === 1)
            return;
        target.enabled = !target.enabled;
        monitors = Layout.pack(next);
        dirty = true;
    }

    function setMode(resolution, rate, scale) {
        if (busy || !selectedMonitor)
            return;
        const match = /^(\d+)x(\d+)$/.exec(resolution.trim());
        if (!match || !/^\d+(\.\d+)?$/.test(rate.trim()) || !/^\d+(\.\d+)?$/.test(scale.trim())) {
            error = "Use a resolution such as 2560x1440 and numeric refresh / scale values.";
            return;
        }
        const width = Number(match[1]), height = Number(match[2]), hz = Number(rate), factor = Number(scale);
        if (width < 320 || width > 16384 || height < 200 || height > 16384 || hz < 1 || hz > Layout.maxRefresh(selectedMonitor, resolution) + .01 || factor < 5 / 6 - .000001 || factor > 3) {
            error = "Resolution, refresh rate or scale is outside the supported range.";
            return;
        }
        if ([width, height].some(n => Math.abs(n / factor - Math.round(n / factor)) > .01)) {
            error = "Choose a scale that gives whole logical pixels.";
            return;
        }
        const next = Layout.copy(monitors), target = next.find(m => m.name === selected);
        Object.assign(target, {
            width: width,
            height: height,
            rate: hz,
            scale: factor
        });
        monitors = Layout.pack(next);
        dirty = true;
        error = "";
    }

    function chooseResolution(resolution) {
        if (!selectedMonitor)
            return;
        const parts = resolution.split("x").map(Number);
        const candidate = Object.assign({}, selectedMonitor, {
            width: parts[0],
            height: parts[1]
        });
        const factors = Layout.scales(candidate);
        const factor = factors.includes(selectedMonitor.scale) ? selectedMonitor.scale : 1;
        setMode(resolution, String(Math.min(selectedMonitor.rate, Layout.maxRefresh(selectedMonitor, resolution))), String(factor));
    }

    function setRefresh(value) {
        if (!selectedMonitor)
            return;
        setMode(selectedMonitor.width + "x" + selectedMonitor.height, value, String(selectedMonitor.scale));
    }

    function setScale(value) {
        if (!selectedMonitor)
            return;
        setMode(selectedMonitor.width + "x" + selectedMonitor.height, String(selectedMonitor.rate), String(value));
    }

    function apply() {
        if (busy || !dirty || !monitors.length)
            return;
        error = "";
        receivedResult = false;
        transaction.command = ["python3", helper, "preview", JSON.stringify({
                revision: revision,
                mode: mode,
                monitors: monitors
            })];
        transaction.running = true;
    }

    function keep() {
        if (previewing) {
            previewing = false;
            transaction.write("keep\n");
        }
    }

    function revert() {
        if (transaction.running)
            transaction.write("revert\n");
        previewing = false;
    }

    onActiveChanged: {
        if (active)
            refresh();
        else
            revert();
    }

    Process {
        id: inspect
        command: ["python3", root.helper, "inspect"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const state = JSON.parse(text);
                    if (state.event !== "state")
                        throw new Error(state.message);
                    root.mode = Layout.detect(state.monitors);
                    root.monitors = Layout.pack(state.monitors);
                    root.revision = state.revision;
                    root.dirty = false;
                    if (!root.monitors.some(m => m.name === root.selected))
                        root.selected = root.monitors[0]?.name || "";
                } catch (error) {
                    root.error = "Could not read displays: " + error.message;
                }
            }
        }
        onExited: code => {
            if (code !== 0 && !root.error)
                root.error = "Display discovery failed. Check Hyprland and python3.";
        }
    }

    Process {
        id: transaction
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data);
                    if (message.event === "preview") {
                        root.deadline = Date.now() + message.seconds * 1000;
                        root.previewSeconds = message.seconds;
                        root.secondsLeft = message.seconds;
                        root.previewing = true;
                    } else if (message.event === "error") {
                        root.error = message.message;
                        root.receivedResult = true;
                    } else if (message.event === "kept" || message.event === "reverted") {
                        root.previewing = false;
                        root.receivedResult = true;
                    }
                } catch (_) {
                    root.error = "Invalid response from the display controller.";
                }
            }
        }
        onExited: code => {
            root.previewing = false;
            if (!root.receivedResult)
                root.error = "The display controller stopped unexpectedly.";
            // Re-read even after a failure: the layout was rolled back, so the
            // map would otherwise keep showing the arrangement that was tried.
            if (root.active)
                Qt.callLater(() => root.refresh(true));
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.active && root.previewing
        onTriggered: root.secondsLeft = Math.max(0, Math.ceil((root.deadline - Date.now()) / 1000))
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.active && !root.busy && ["monitoradded", "monitorremoved", "configreloaded"].includes(event.name)) {
                if (root.dirty)
                    root.error = "Displays changed. Refresh the map before applying.";
                else
                    refreshDelay.restart();
            }
        }
    }

    Timer {
        id: refreshDelay
        interval: 200
        onTriggered: if (root.active)
            root.refresh()
    }
}
