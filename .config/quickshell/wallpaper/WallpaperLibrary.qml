import QtQuick
import Quickshell
import Quickshell.Io

// The wallpapers listed by the index script, and which one is applied.
Scope {
    id: root

    required property string script
    readonly property alias model: items
    property string current: ""

    // The index was read and the model filled.
    signal loaded

    function load() {
        indexProcess.command = ["python3", script];
        indexProcess.running = true;
    }

    function parse(raw) {
        const text = String(raw || "").trim();
        items.clear();

        if (text === "")
            return;
        try {
            const data = JSON.parse(text);
            current = String(data.current || "");

            const entries = Array.isArray(data.items) ? data.items : [];
            for (let i = 0; i < entries.length; ++i) {
                const entry = entries[i];
                items.append({
                    key: entry.key || "",
                    src: entry.src || "",
                    preview: entry.preview || "",
                    frame: entry.frame || "",
                    type: String(entry.type || "image").trim(),
                    name: entry.name || ""
                });
            }

            loaded();
        } catch (e) {
            console.warn("[WallpaperPicker] index parse error:", e);
        }
    }

    ListModel {
        id: items
    }

    Process {
        id: indexProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (typeof text === "function") ? text() : text;
                root.parse(raw);
            }
        }
    }
}
