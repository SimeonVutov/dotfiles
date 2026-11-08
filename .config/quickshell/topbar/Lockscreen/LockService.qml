import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    readonly property bool secure: session.secure
    readonly property var authenticator: authentication
    readonly property var colors: palette

    function requestLock() {
        if (session.locked)
            return;

        session.locked = true;
    }

    LayoutStore {
        id: layoutStore
    }

    LockPalette {
        id: palette
    }

    Authenticator {
        id: authentication

        enabled: session.secure
        onAuthenticated: {
            if (session.secure)
                session.locked = false;
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
            return root.secure ? "locked" : session.locked ? "locking" : "unlocked";
        }
    }

    // The compositor keeps a crashed locker locked. Only successful PAM
    // authentication above releases the lock; IPC has no unlock endpoint.
}
