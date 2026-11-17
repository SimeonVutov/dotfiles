import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color text: "#ffffff"
    property color accent: "#555555"

    function load() {
        try {
            const colors = JSON.parse(file.text());
            if (colors.text)
                text = colors.text;

            if (colors.accent)
                accent = colors.accent;
        } catch (exception) {
            // The default palette also works before the first wallpaper change.
        }
    }

    FileView {
        id: file

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/matugen/colors-lockscreen.json"
        printErrors: false
        watchChanges: true
        onLoaded: root.load()
        onFileChanged: reload()
    }
}
