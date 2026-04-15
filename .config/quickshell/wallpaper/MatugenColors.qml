import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base:     "#1e1e2e"
    property color mantle:   "#181825"
    property color crust:    "#11111b"
    property color text:     "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color blue:     "#89b4fa"
    property color sapphire: "#74c7ec"
    property color green:    "#a6e3a1"
    property color teal:     "#94e2d5"
    property color red:      "#f38ba8"
    property color maroon:   "#eba0ac"
    property color peach:    "#fab387"
    property color yellow:   "#f9e2af"
    property color mauve:    "#cba6f7"
    property color pink:     "#f5c2e7"

    property string _rawJson: ""

    Process {
        id: colorReader
        command: ["cat", "/tmp/qs_colors.json"]

        stdout: StdioCollector {
            onStreamFinished: {
                const content = (typeof text === "function") ? text() : text
                const txt = String(content || "").trim()
                if (txt === "" || txt === root._rawJson)
                    return

                root._rawJson = txt

                try {
                    const c = JSON.parse(txt)
                    if (c.base)     root.base     = c.base
                    if (c.mantle)   root.mantle   = c.mantle
                    if (c.crust)    root.crust    = c.crust
                    if (c.text)     root.text     = c.text
                    if (c.subtext0) root.subtext0 = c.subtext0
                    if (c.subtext1) root.subtext1 = c.subtext1
                    if (c.surface0) root.surface0 = c.surface0
                    if (c.surface1) root.surface1 = c.surface1
                    if (c.surface2) root.surface2 = c.surface2
                    if (c.overlay0) root.overlay0 = c.overlay0
                    if (c.overlay1) root.overlay1 = c.overlay1
                    if (c.blue)     root.blue     = c.blue
                    if (c.sapphire) root.sapphire = c.sapphire
                    if (c.green)    root.green    = c.green
                    if (c.teal)     root.teal     = c.teal
                    if (c.red)      root.red      = c.red
                    if (c.maroon)   root.maroon   = c.maroon
                    if (c.peach)    root.peach    = c.peach
                    if (c.yellow)   root.yellow   = c.yellow
                    if (c.mauve)    root.mauve    = c.mauve
                    if (c.pink)     root.pink     = c.pink
                } catch (e) {
                    console.warn("[MatugenColors] JSON parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: colorReader.running = true
    }
}
