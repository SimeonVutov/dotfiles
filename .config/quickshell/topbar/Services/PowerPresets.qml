pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

Singleton {
    id: root
    readonly property string currentMode: {
        const active = canonical(activeConfig.path ? activeConfig.text() : "");
        const ultimate = canonical(ultimateConfig.path ? ultimateConfig.text() : "");
        const balanced = canonical(balancedConfig.path ? balancedConfig.text() : "");
        if (!active)
            return "";
        if (ultimate && active === ultimate)
            return "ultimate";
        if (balanced && active === balanced)
            return "balanced";
        return ultimate && balanced ? "custom" : "";
    }
    readonly property string label: currentMode ? currentMode.charAt(0).toUpperCase() + currentMode.slice(1) : "Unknown"

    // Compare effective INI settings, ignoring formatting and comments.
    function canonical(text) {
        let section = "";
        const values = {};
        for (const raw of text.split("\n")) {
            const line = raw.replace(/\s*[#;].*$/, "").trim();
            if (!line)
                continue;
            const heading = line.match(/^\[([^\]]+)\]$/);
            if (heading) {
                section = heading[1].trim().toLowerCase();
                continue;
            }
            const split = line.indexOf("=");
            if (split < 0)
                continue;
            values[section + "." + line.slice(0, split).trim().toLowerCase()] = line.slice(split + 1).trim();
        }
        return Object.keys(values).sort().map(key => key + "=" + values[key]).join("\n");
    }

    function refresh() {
        activeConfig.reload();
        if (ultimateConfig.path)
            ultimateConfig.reload();
        if (balancedConfig.path)
            balancedConfig.reload();
    }
    FileView {
        id: activeConfig
        path: Config.hardware.powerConfig
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: ultimateConfig
        path: Config.hardware.powerPresets.ultimate
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: balancedConfig
        path: Config.hardware.powerPresets.balanced
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}
