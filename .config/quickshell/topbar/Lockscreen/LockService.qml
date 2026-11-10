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

    function requestLock() {
        if (session.locked || lockRequested)
            return;

        Quickshell.watchFiles = false;
        lockRequested = true;
        layoutStore.reload();
        activateLock();
    }

    function activateLock() {
        if (!lockRequested || !layoutStore.ready)
            return;

        session.locked = true;
        lockRequested = false;
        if (!session.locked)
            Quickshell.watchFiles = true;
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

        enabled: session.secure
        attemptLimit: root.passwordSettings.attemptLimit
        timeoutMinutes: root.passwordSettings.retryTimeoutMinutes
        onAuthenticated: {
            if (session.secure) {
                session.locked = false;
                Quickshell.watchFiles = true;
            }
        }
    }

    WlSessionLock {
        id: session

        WlSessionLockSurface {
            color: "#0a0a0a"

            LockFace {
                anchors.fill: parent
                controller: root
                store: layoutStore
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
