import QtQuick
import Quickshell
import Quickshell.Io
import "Grid.js" as Grid

Item {
    id: root
    readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    property string storagePath: directory + "/lockscreen-layout.json"
    property var layout: Grid.initial()
    property string error: ""
    property bool ready: false
    property bool saving: false
    property var pending: null
    signal saved
    signal saveFailed

    function load() {
        try {
            const text = file.text().trim();
            root.layout = text ? Grid.validate(JSON.parse(text)) : Grid.initial();
            root.error = "";
        } catch (exception) {
            // A malformed layout must never prevent the password surface loading.
            root.layout = Grid.initial();
            root.error = "Using the default layout: " + exception.message;
        }
        root.ready = true;
    }
    function save(next) {
        if (!ready || saving)
            return false;
        try {
            pending = Grid.validate(next);
        } catch (exception) {
            error = exception.message;
            return false;
        }
        saving = true;
        error = "";
        file.setText(JSON.stringify(pending, null, 2) + "\n");
        return true;
    }
    Process {
        command: ["mkdir", "-p", root.directory]
        running: true
        onExited: code => {
            if (code !== 0) {
                root.error = "Cannot open lockscreen layout storage.";
                return;
            }
            file.path = root.storagePath;
        }
    }
    FileView {
        id: file
        watchChanges: true
        atomicWrites: true
        blockWrites: false
        printErrors: false
        onLoaded: root.load()
        onLoadFailed: error => {
            root.ready = true;
            if (error !== FileViewError.FileNotFound)
                root.error = "Cannot read the saved layout; using the default.";
        }
        onFileChanged: if (!root.saving)
            reload()
        onSaved: {
            root.layout = root.pending;
            root.pending = null;
            root.saving = false;
            root.saved();
        }
        onSaveFailed: {
            root.pending = null;
            root.saving = false;
            root.error = "Could not save the layout. Your previous layout is unchanged.";
            root.saveFailed();
        }
    }
}
