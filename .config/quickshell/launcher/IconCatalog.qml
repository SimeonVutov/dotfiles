import QtQuick
import Quickshell
import Quickshell.Io

// Remembers which application icons exist in the icon theme. Asking costs about
// 4 ms an icon, which added up to 220 ms of frozen start-up for a launcher that
// starts afresh each time, so the answers are kept between launches. An icon
// seen for the first time is used as it is (Quickshell loads it off the main
// thread) and checked once the launcher has settled, one icon per tick; if it
// turns out to be missing, the satellite shows the app's initial instead of
// Qt's checkerboard.
Item {
    id: root

    // The icon names on show, and whether the launcher is idle enough to check.
    property var names: []
    property bool idle: false

    // name -> whether the theme has it. Replaced rather than edited, so
    // bindings that read it update.
    property var known: ({})
    property var queue: []
    property bool dirty: false
    // Answers are dropped after this long, in case the icon theme changed.
    readonly property real maxAge: 14 * 24 * 3600 * 1000

    // The image source for an icon: nothing for one known to be missing.
    function source(name) {
        return !name || known[name] === false ? "" : Quickshell.iconPath(name);
    }

    function verifyNext() {
        const name = queue[0];
        queue = queue.slice(1);
        const next = Object.assign({}, known);
        next[name] = Quickshell.iconPath(name, true) !== "";
        known = next;
        dirty = true;
        if (!queue.length)
            save();
    }

    function save() {
        if (!dirty)
            return;

        const kept = {};
        for (const name of names) {
            if (known[name] !== undefined)
                kept[name] = known[name];
        }
        // The age counts from the first answer in this file.
        file.adapter.stamp = file.adapter.stamp > 0 && Date.now() - file.adapter.stamp < maxAge ? file.adapter.stamp : Date.now();
        file.adapter.known = kept;
        file.writeAdapter();
        dirty = false;
    }

    onNamesChanged: queue = Array.from(new Set(names)).filter(name => name && known[name] === undefined)

    Component.onCompleted: {
        if (file.adapter.stamp > 0 && Date.now() - file.adapter.stamp < maxAge)
            known = Object.assign({}, file.adapter.known);
        queue = Array.from(new Set(names)).filter(name => name && known[name] === undefined);
    }
    Component.onDestruction: save()

    Timer {
        interval: 20
        repeat: true
        running: root.idle && root.queue.length > 0
        onTriggered: root.verifyNext()
    }

    FileView {
        id: file

        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell-launcher-icons.json"
        blockLoading: true
        blockWrites: true
        // The first launch has no file yet.
        printErrors: false

        JsonAdapter {
            property double stamp: 0
            property var known: ({})
        }
    }
}
