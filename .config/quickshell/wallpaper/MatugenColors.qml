import QtQuick
import Quickshell.Io

Item {
    id: root

    readonly property string colorCachePath: "/tmp/qs_colors.json"

    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color green: "#a6e3a1"
    property color teal: "#94e2d5"
    property color red: "#f38ba8"
    property color maroon: "#eba0ac"
    property color peach: "#fab387"
    property color yellow: "#f9e2af"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"

    property string loadedJson: ""

    readonly property var colorNames: ["base", "mantle", "crust", "text", "subtext0", "subtext1", "surface0", "surface1", "surface2", "overlay0", "overlay1", "blue", "sapphire", "green", "teal", "red", "maroon", "peach", "yellow", "mauve", "pink"]

    function loadColors() {
        colorFile.reload();

        const text = String(colorFile.text() || "").trim();
        if (!text || text === loadedJson)
            return;

        try {
            const colors = JSON.parse(text);
            for (const name of colorNames) {
                if (colors[name])
                    root[name] = colors[name];
            }

            loadedJson = text;
        } catch (error) {
            console.warn("[MatugenColors] JSON parse error:", error);
        }
    }

    FileView {
        id: colorFile

        path: root.colorCachePath
        watchChanges: true
        blockAllReads: true
        printErrors: false
        onFileChanged: root.loadColors()
    }

    Component.onCompleted: loadColors()
}
