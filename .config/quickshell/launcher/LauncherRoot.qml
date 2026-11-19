import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Common

// One opening of the launcher, whose process ends when it closes. The shared
// OverlaySession brings in the desktop capture and decides when the window maps.
Item {
    id: root

    // The launcher inside the window, once it is built.
    readonly property var launcher: windowLoader.item?.launcher ?? null

    // Opens as soon as the process is up.
    Component.onCompleted: session.open()

    function focusSearch() {
        launcher?.focusSearch();
    }

    function close() {
        if (!session.opened)
            return;

        // Nothing is on screen before the window maps, so there is nothing to land.
        if (!session.armed)
            session.finish();
        else
            launcher?.cancel();
    }

    function launch(entry) {
        if (!entry) {
            launcher?.launchFailed("No application to launch");
            return;
        }

        try {
            entry.execute();
            session.finish();
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

    OverlaySession {
        id: session

        capturePrefix: "launcher"
        onArmedChanged: {
            if (armed)
                Qt.callLater(root.focusSearch);
        }
    }

    LazyLoader {
        id: windowLoader

        active: session.opened

        PanelWindow {
            readonly property alias launcher: menu

            visible: session.armed
            screen: session.targetScreen
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
                width: session.targetScreen?.width ?? 0
                height: session.targetScreen?.height ?? 0
                presenting: session.armed
                snapshot: session.snapshotSource
                onSnapshotReady: session.arm()
                onDismissed: session.finish()
                onLaunchRequested: entry => root.launch(entry)
            }
        }
    }
}
