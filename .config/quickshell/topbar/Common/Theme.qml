pragma Singleton

import QtQuick
import Quickshell

// Every colour, metric and duration the bar uses. Restyling the whole bar
// means editing this file and nothing else.
Singleton {
    id: root

    // ── Colours ────────────────────────────────────────────────
    readonly property color pillBackground: "#000000"
    readonly property real pillOpacity: 0.8
    readonly property color text: "#FFFFFF"

    // Workspace buttons: inactive is plain text, active/hover is an inverted chip.
    readonly property color workspaceActiveBackground: "#CCCCCC"
    readonly property color workspaceActiveText: "#000000"

    // Alert states, applied by the battery and hardware modules.
    readonly property color warningBackground: "#ffbe61"
    readonly property color warningText: "#000000"
    readonly property color criticalBackground: "#f53c3c"
    readonly property color criticalText: "#FFFFFF"
    readonly property color criticalForeground: "#BF616A"

    // The power button draws bare on the bar with no pill behind it.
    readonly property color powerButton: "#000000"

    // ── Popups ─────────────────────────────────────────────────
    readonly property color popupBackground: "#0A0A0A"
    // Opaque: these panels carry small text, and letting the desktop show
    // through made the calendar hard to read.
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
    readonly property int pillPaddingV: 2
    readonly property int pillSpacing: 15      // gap between pills
    readonly property int pillMarginV: 5
    readonly property int groupSpacing: 10     // gap between items inside one pill

    // waybar gave active buttons min-width:40 on top of 5px side padding.
    readonly property int workspaceMinWidth: 50
    readonly property int workspaceSpacing: 6
    readonly property int workspacePaddingH: 5

    // Items grouped inside one pill carried 5px of their own side padding,
    // which is what put 10px between them and 5px at the group's edges.
    readonly property int groupItemPaddingH: 5

    // ── Typography ─────────────────────────────────────────────
    // waybar asked for "Roboto, Helvetica, Arial, sans-serif". Roboto isn't
    // installed, so fontconfig substitutes FreeSans — asking for Roboto here
    // resolves the same way, and would pick up the real thing if it's ever
    // installed. Nerd Font icon glyphs come in through fontconfig's fallback,
    // exactly as they did under waybar.
    readonly property string fontFamily: "Roboto"
    // waybar's `*` rule set 14px and only #clock/#pulseaudio/#battery/#network
    // overrode it to 15px, so anything grouped inside a pill (cpu, memory,
    // temperature, bluetooth, the media title, workspace numbers) stayed at 14.
    readonly property int fontSize: 15
    readonly property int fontSizeSmall: 14
    readonly property int powerFontSize: 20
    readonly property int mediaControlFontSize: 22

    // ── Motion ─────────────────────────────────────────────────
    readonly property int durationFast: 150
    readonly property int durationNormal: 300   // waybar used 0.3s ease-in-out
    readonly property int durationSlow: 450
    readonly property int easing: Easing.InOutQuad
    readonly property int easingEmphasized: Easing.OutCubic
}
