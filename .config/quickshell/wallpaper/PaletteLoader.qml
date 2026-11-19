import QtQuick
import Quickshell
import Quickshell.Io

// Extracts a colour palette for a wallpaper with a script, one run at a time.
// A newer request supersedes older ones, and the output of a run that was
// replaced or cancelled is discarded.
Scope {
    id: root

    required property string script
    property bool loading: false
    property var colors: []

    // A palette arrived for the latest request.
    signal ready

    // Forgets the palette and cancels any request that is waiting or running.
    function reset() {
        run.generation++;
        colors = [];
        loading = false;
        run.queued = null;
    }

    // Replaces the palette with one for this wallpaper. The script runs now,
    // or as soon as the previous run ends.
    function request(source, type, frame) {
        reset();
        run.queued = {
            generation: run.generation,
            source: source,
            type: type,
            frame: frame
        };
        loading = true;
        startQueued();
    }

    function startQueued() {
        if (process.running || !run.queued)
            return;

        const next = run.queued;
        run.queued = null;
        run.runningGeneration = next.generation;
        run.output = "";
        process.command = ["bash", script, next.source, next.type, next.frame];
        process.running = true;
    }

    function accept(raw) {
        if (run.runningGeneration !== run.generation)
            return;

        const cleaned = String(raw || "").trim();
        loading = false;

        if (!cleaned) {
            colors = [];
            return;
        }

        try {
            const parsed = JSON.parse(cleaned);
            colors = Array.isArray(parsed) ? parsed : [];
            ready();
        } catch (error) {
            console.warn("[WallpaperPicker] Failed to parse palette JSON:", error);
            colors = [];
        }
    }

    // Bookkeeping that discards stale output: the generation counts requests,
    // and only output from the run of the current generation is accepted.
    QtObject {
        id: run

        property int generation: 0
        property int runningGeneration: 0
        property var queued: null
        property string output: ""
    }

    Process {
        id: process
        running: false

        stdout: StdioCollector {
            onStreamFinished: run.output = (typeof text === "function") ? text() : text
        }

        onExited: (code, status) => {
            if (run.runningGeneration === run.generation) {
                if (code === 0 && status === 0)
                    root.accept(run.output);
                else {
                    root.loading = false;
                    root.colors = [];
                }
            }

            Qt.callLater(root.startQueued);
        }
    }
}
