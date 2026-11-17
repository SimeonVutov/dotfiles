import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WidgetCatalog.js" as Catalog

Item {
    id: root

    readonly property bool secure: session.secure
    readonly property var authenticator: authentication
    readonly property var colors: palette
    readonly property var passwordSettings: Catalog.find("authentication").resolve(layoutStore.layout.widgets.find(widget => widget.type === "authentication")?.settings)
    property bool lockRequested: false
    property bool unlocking: false
    property real unlockProgress: 0

    function requestLock() {
        if (session.locked || lockRequested)
            return;

        Quickshell.watchFiles = false;
        lockRequested = true;
        // Read the saved layout before constructing any monitor surfaces.
        layoutStore.reload();
        snapshots.start();
    }

    function activateLock() {
        if (!lockRequested || !layoutStore.ready || !snapshots.ready)
            return;

        session.locked = true;
        lockRequested = false;
        if (!session.locked) {
            snapshots.release();
            Quickshell.watchFiles = true;
        }
    }

    DesktopSnapshot {
        id: snapshots

        onReadyChanged: root.activateLock()
    }

    LayoutStore {
        id: layoutStore

        onReadyChanged: root.activateLock()
    }

    LockPalette {
        id: palette
    }

    Authenticator {
        id: authentication

        enabled: session.secure && !root.unlocking
        attemptLimit: root.passwordSettings.attemptLimit
        timeoutMinutes: root.passwordSettings.retryTimeoutMinutes
        onAuthenticated: {
            if (session.secure && !root.unlocking) {
                root.unlocking = true;
                unlockAnimation.start();
            }
        }
    }

    NumberAnimation {
        id: unlockAnimation

        target: root
        property: "unlockProgress"
        from: 0
        to: 1
        duration: layoutStore.layout.animation.type === "none" ? 0 : layoutStore.layout.animation.duration
        easing.type: Easing.InOutSine
        onFinished: {
            session.locked = false;
            snapshots.release();
            root.unlocking = false;
            root.unlockProgress = 0;
            Quickshell.watchFiles = true;
            // Re-enabling the watcher does not detect edits made while locked.
            Qt.callLater(() => {
                if (!session.locked && !root.lockRequested)
                    Quickshell.reload(false);
            });
        }
    }

    WlSessionLock {
        id: session

        onLockedChanged: if (!locked && !root.lockRequested)
            snapshots.release()

        WlSessionLockSurface {
            id: lockSurface
            color: "#0a0a0a"

            LockFace {
                anchors.fill: parent
                presenting: session.secure && lockSurface.visible
                controller: root
                store: layoutStore
                snapshot: snapshots.contains(lockSurface.screen) ? snapshots.source : ""
                snapshotRect: snapshots.rectangle(lockSurface.screen)
                exiting: root.unlocking
                exitProgress: root.unlockProgress
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            root.requestLock();
        }

        function status(): string {
            return root.secure ? "locked" : session.locked || root.lockRequested ? "locking" : "unlocked";
        }
    }

    // The compositor keeps a crashed locker locked. Only successful PAM
    // authentication above releases the lock; IPC has no unlock endpoint.
}
