import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// One opening of the session menu, whose process ends when it closes. The
// shared OverlaySession brings in the desktop capture; the menu arms itself
// once it has decoded it, and the session steps in only when the capture fails
// or is late.
Item {
    id: root

    // The menu's window, once it is built.
    readonly property var view: viewLoader.item

    // Opens as soon as the process is up.
    Component.onCompleted: session.open()

    function close() {
        if (!session.opened)
            return;

        if (view?.armed)
            view.dismiss();
        else
            session.finish();
    }

    function runAction(action) {
        if (action === "lock") {
            session.finish();
            Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/scripts/lock-screen.sh"]);
            return;
        }

        const commands = {
            exit: ["hyprctl", "dispatch", "hl.dsp.exit()"],
            reboot: ["systemctl", "reboot"],
            shutdown: ["systemctl", "poweroff"],
            suspend: ["sh", "-c", "sh ~/.config/scripts/lock-screen.sh && systemctl suspend"],
            hibernate: ["sh", "-c", "sh ~/.config/scripts/lock-screen.sh && systemctl hibernate"]
        };
        if (!commands[action])
            return;

        actionProcess.command = commands[action];
        actionProcess.running = true;
    }

    IpcHandler {
        target: "menu"

        function close(): void {
            root.close();
        }

        // The menu exists only while open, so a toggle can only close it.
        function toggle(): void {
            root.close();
        }
    }

    OverlaySession {
        id: session

        capturePrefix: "session-menu"
        // The menu used to wait up to half a second for its capture.
        captureDeadline: 500
        onArmedChanged: {
            if (armed)
                root.view?.arm();
        }
    }

    // Once the menu maps (it arms itself when the snapshot is decoded), a late
    // snapshot would pop in mid-animation, so the session stops accepting one.
    Connections {
        target: root.view

        function onArmedChanged() {
            if (target.armed)
                session.arm();
        }

        // The arrival animation clears the backdrop when it is done with it.
        function onBackdropChanged() {
            if (!target.backdrop)
                session.releaseSnapshot();
        }
    }

    Process {
        id: actionProcess

        onExited: (code, status) => {
            if (code === 0 && status === 0)
                session.finish();
            else
                root.view?.showError("Action failed. Try again or press Escape.");
        }
    }

    LazyLoader {
        id: viewLoader

        active: session.opened

        SessionMenuView {
            monitor: session.monitor
            presenting: session.opened
            busy: actionProcess.running
            backdrop: session.snapshotSource
            onDismissed: session.finish()
            onActionRequested: action => root.runAction(action)
        }
    }
}
