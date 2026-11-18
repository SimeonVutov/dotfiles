import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

// One opening of the launcher, whose process ends when it closes. The desktop
// is captured while the process starts (app-launcher.sh does it and names the
// file), so the capture is usually done by the time the window is built. The
// window maps once the snapshot is ready or the capture deadline expires.
//
// Nothing here may wait on a Timer: with the clock-driven animation driver
// (QSG_USE_SIMPLE_ANIMATION_DRIVER) timers only run once a window is on screen,
// and this process has none until the launcher maps.
Item {
    id: root

    // The monitor holding the focus, as found by app-launcher.sh.
    readonly property string monitor: Quickshell.env("QS_LAUNCHER_MONITOR") || Quickshell.screens[0]?.name || ""
    readonly property var targetScreen: Quickshell.screens.find(screen => screen.name === monitor) || Quickshell.screens[0]
    // The launcher inside the window, once it is built.
    readonly property var launcher: windowLoader.item?.launcher ?? null
    // A capture made ahead of this process, and the marker that appears once it
    // is complete. Without one, the capture is made here.
    readonly property string preparedCapture: Quickshell.env("QS_LAUNCHER_CAPTURE")

    property bool opened: false
    property bool armed: false
    // The desktop capture, handed to the launcher.
    property string snapshotSource: ""

    // Opens as soon as the process is up.
    Component.onCompleted: open()

    function open() {
        if (opened)
            return;

        if (preparedCapture) {
            // Before the window, so the wait runs while the window is built.
            awaitCapture.running = true;
            opened = true;
            return;
        }

        // Before the window: the capture runs while the window is built.
        const capturing = capture.start(monitor);
        opened = true;
        if (!capturing)
            arm();
    }

    // Idempotent: whichever of snapshotReady, a failed capture or the capture
    // deadline comes first is the one that maps the window.
    function arm() {
        if (!opened || armed)
            return;

        armed = true;
        Qt.callLater(focusSearch);
    }

    function focusSearch() {
        launcher?.focusSearch();
    }

    function close() {
        if (!opened)
            return;

        // Nothing is on screen before the window maps, so there is nothing to land.
        if (!armed)
            finish();
        else
            launcher?.cancel();
    }

    // The process ends here, taking the window and everything else with it.
    function finish() {
        if (!opened)
            return;

        opened = false;
        armed = false;
        // The process ends before the capture's own clean-up would run.
        capture.cancel();
        capture.release();
        if (preparedCapture)
            Quickshell.execDetached(["rm", "-f", "--", preparedCapture, preparedCapture + ".part", preparedCapture + ".ok"]);
        Qt.quit();
    }

    function launch(entry) {
        if (!entry) {
            launcher?.launchFailed("No application to launch");
            return;
        }

        try {
            entry.execute();
            finish();
        } catch (error) {
            const name = entry.name || "application";
            const message = "Could not launch " + name;
            launcher?.launchFailed(message);
            console.warn(message, error);
        }
    }

    IpcHandler {
        target: "launcher"

        function close(): void {
            root.close();
        }

        // The launcher exists only while open, so a toggle can only close it.
        function toggle(): void {
            root.close();
        }
    }

    DesktopCapture {
        id: capture

        prefix: "launcher"

        onCompleted: source => {
            // A capture that lands after arming has missed its slot; handing it
            // over now would pop the desktop in mid-animation.
            if (root.opened && !root.armed)
                root.snapshotSource = source;
            else
                capture.release();
        }

        onFailed: {
            if (root.opened)
                root.arm();
        }
    }

    // Waits for the prepared capture's marker, which comes last so that a
    // snapshot is never read half written. It ends at once if the marker is
    // there already, and gives up after about 250 ms, when the launcher maps
    // without a snapshot instead of waiting for the compositor indefinitely.
    Process {
        id: awaitCapture

        command: ["sh", "-c", 'n=0; while [ ! -e "$1" ] && [ "$n" -lt 40 ]; do sleep 0.005; n=$((n + 1)); done; [ -e "$1" ]',
            "sh", root.preparedCapture + ".ok"]
        onExited: (code, status) => {
            if (!root.opened || root.armed)
                return;

            if (code === 0 && status === 0)
                root.snapshotSource = "file://" + root.preparedCapture;
            else
                root.arm();
        }
    }

    LazyLoader {
        id: windowLoader

        active: root.opened

        PanelWindow {
            readonly property alias launcher: menu

            visible: root.armed
            screen: root.targetScreen
            // The flight covers the whole screen with the captured desktop or space
            // from its first frame, so the surface is opaque: the compositor can skip
            // drawing (and blurring) the windows underneath on every frame.
            color: "black"
            surfaceFormat.opaque: true
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-launcher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Launcher {
                id: menu

                // The screen's size rather than the window's, which starts at zero
                // and would make the launcher lay itself out again as the first
                // frames draw.
                width: root.targetScreen?.width ?? 0
                height: root.targetScreen?.height ?? 0
                presenting: root.armed
                snapshot: root.snapshotSource
                onSnapshotReady: root.arm()
                onDismissed: root.finish()
                onLaunchRequested: entry => root.launch(entry)
            }
        }
    }

    Component.onDestruction: {
        capture.cancel();
        capture.release();
    }
}
