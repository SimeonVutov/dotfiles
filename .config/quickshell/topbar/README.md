Run the bar with `qs -c topbar`.

All expanded panels inherit `Ui/PopupPanel.qml`. It owns centered anchoring,
chrome, motion, dismissal, padding, the content grid, and a floating-menu layer.
`Ui/PanelLayout.qml` supplies the invisible grid defaults. Content uses
`Layout.fillWidth`, `Layout.columnSpan`, and implicit sizes; avoid anchoring
items managed directly by the grid.

```qml
import QtQuick.Layouts
import qs.Ui

PopupPanel {
    panelWidth: 400
    columns: 2

    BarText {
        Layout.columnSpan: 2
        Layout.fillWidth: true
        text: "My panel"
    }
}
```

`Theme.qml` contains visual tokens. `Config.qml` controls module placement,
hardware paths, sampling cadence, history length, and session graph toggles.
`Registry.qml` maps module IDs to their implementations. Modules own their popups.

`Players.qml` owns media selection and transport. `MediaSourcePicker.qml` shows
registered MPRIS sources; browser tabs must expose separate sources to be listed
separately. `PlaybackIndicator.qml` animates only during visible playback at a constant pace
set by `Config.media.animationStepDuration`. It does not analyze audio.

`SysMon.qml` owns the single sampler. Visible graphs use one-second samples;
without graphs the bar uses its original two-second cadence. `ResourceGraph.qml`
owns each graph subscription and toggle; `StripChart.qml` draws bounded history
only when new data arrives. `HardwareControls.qml` owns fan commands and launches
power presets in a terminal for sudo authentication. `PowerPresets.qml` compares
`Config.hardware.powerConfig` with the files in `Config.hardware.powerPresets`.
Set those paths to the script's actual preset files; unmatched configurations
show Custom, and missing/unreadable presets show Unknown.
