pragma Singleton
import QtQuick
import Quickshell

// Same neutral palette as the session menu; launcher stays independently usable.
Singleton {
    readonly property color abyss: "#000000"
    readonly property color background: "#0A0A0A"
    readonly property color surface: "#191919"
    readonly property color border: "#343434"
    readonly property color orbit: "#232323"
    readonly property color text: "#EEEEEE"
    readonly property color muted: "#939393"
    readonly property string font: "Roboto"
    readonly property int motion: 180
}
