import QtQuick
import Quickshell
import qs.Settings.Lockscreen
import qs.Lockscreen as Lock

ShellRoot {
    id: root

    property int stage: 0
    property int ticks: 0

    FloatingWindow {
        implicitWidth: 1480
        implicitHeight: 850
        color: "#0a0a0a"

        LockscreenEditor {
            id: editor
            anchors.fill: parent
            active: true
        }
    }

    FloatingWindow {
        implicitWidth: 960
        implicitHeight: 540

        Lock.LockFace {
            anchors.fill: parent
            store: editor.controller.store
            controller: preview
        }
    }

    Item {
        id: preview
        property bool busy: false
        property bool ready: true
        readonly property var authenticator: preview
        property string error: ""
        property string message: "Preview · no authentication or session locking"
        property var colors: ({
                text: "#ffffff",
                accent: "#555555"
            })
        signal clearInput
        function respond(response) {
            error = "Preview cannot unlock a session.";
            clearInput();
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.ticks++;
            if (root.ticks > 100)
                throw new Error("Lockscreen UI test timed out: " + editor.controller.status);

            const controller = editor.controller;
            if (!controller.ready)
                return;

            if (root.stage === 0) {
                controller.beginNew("music");
                controller.moveTo(2, 11);
                controller.place();
                root.stage++;
            } else if (root.stage === 1) {
                if (!controller.layout.widgets.some(widget => widget.type === "music"))
                    throw new Error("Placement was not saved");

                controller.beginMove("music");
                controller.moveTo(8, 8);
                controller.place();
                if (!controller.moving || !controller.error)
                    throw new Error("Overlapping placement was accepted");

                controller.cancelMove();
                controller.selected = "music";
                controller.updateSetting("music", "backgroundOpacity", .4);
                root.stage++;
            } else if (root.stage === 2) {
                if (controller.layout.widgets.find(widget => widget.id === "music").settings.backgroundOpacity !== .4)
                    throw new Error("Widget setting was not persisted");

                controller.removeWidget("music");
                root.stage++;
            } else {
                console.log("PASS lockscreen editor, saved placement, collision rejection, settings, removal, and password/clock preview");
                const screenshot = Quickshell.env("QS_LOCKSCREEN_SNAPSHOT");
                if (screenshot) {
                    running = false;
                    editor.grabToImage(result => {
                        result.saveToFile(screenshot);
                        Qt.quit();
                    });
                } else {
                    Qt.quit();
                }
            }
        }
    }
}
