pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ── Colours ────────────────────────────────────────────────
    readonly property color pillBackground: "#000000"
    readonly property real pillOpacity: 0.8
    readonly property color text: "#FFFFFF"

    readonly property color workspaceActiveBackground: "#CCCCCC"
    readonly property color workspaceActiveText: "#000000"

    readonly property color warningBackground: "#ffbe61"
    readonly property color warningText: "#000000"
    readonly property color criticalBackground: "#f53c3c"
    readonly property color criticalText: "#FFFFFF"
    readonly property color powerButton: "#000000"

    // ── Popups ─────────────────────────────────────────────────
    readonly property color popupBackground: "#0A0A0A"
    readonly property real popupOpacity: 1.0
    readonly property color popupBorder: "#2A2A2A"
    readonly property color popupText: "#FFFFFF"
    readonly property color popupSubtleText: "#9A9A9A"
    readonly property color popupAccent: "#FFFFFF"
    readonly property color popupSurface: "#1A1A1A"
    readonly property real popupRadius: 18

    readonly property color graphCpu: "#91B9EE"
    readonly property color graphMemory: "#B5A0DC"
    readonly property color graphTemperature: "#E8AE87"
    readonly property color graphGpu: "#8DC5B0"
    readonly property int popupPadding: 20
    readonly property int popupSpacing: 12
    readonly property int popupSectionSpacing: 18

    // ── Metrics (mirrors the old waybar CSS box model) ─────────
    readonly property int barHeight: 43
    readonly property int pillRadius: 15
    readonly property int pillPaddingH: 15
    readonly property int pillSpacing: 15
    readonly property int pillMarginV: 5

    readonly property int workspaceSpacing: 6

    readonly property int groupItemPaddingH: 5

    // ── Typography ─────────────────────────────────────────────
    // Fontconfig supplies the same fallback chain used by the old Waybar.
    readonly property string fontFamily: "Roboto"
    readonly property int fontSizeTiny: 11
    readonly property int fontSizeCaption: 12
    readonly property int fontSizeLabel: 13
    readonly property int fontSize: 15
    readonly property int fontSizeSmall: 14
    readonly property int fontSizeLarge: 18
    readonly property int fontSizeXLarge: 20
    readonly property int fontSizeDisplay: 40
    readonly property int powerFontSize: 20

    // ── Motion ─────────────────────────────────────────────────
    readonly property int durationFast: 150
    readonly property int durationNormal: 300
    readonly property int easing: Easing.InOutQuad
    readonly property int easingEmphasized: Easing.OutCubic

    // ── Overlay (Launcher / SessionMenu) ───────────────────────
    readonly property color overlayAbyss: "#000000"
    readonly property color overlayBackground: "#0A0A0A"
    readonly property color overlaySurface: "#191919"
    readonly property color overlaySurfaceHover: "#242424"
    readonly property color overlayBorder: "#343434"
    readonly property color overlayBorderBright: "#505050"
    readonly property color overlayOrbit: "#232323"
    readonly property color overlayText: "#EEEEEE"
    readonly property color overlayMuted: "#939393"
    readonly property color overlaySelection: "#555555"
    readonly property int overlayMotion: 180
}
