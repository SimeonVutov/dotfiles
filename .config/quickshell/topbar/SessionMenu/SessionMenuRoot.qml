import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Lives inside the topbar process (see ../shell.qml) instead of running as
// its own Quickshell instance, so opening the menu costs no process start,
// no QML load and no shader compile — just an IPC call:
//
//   qs -c topbar ipc call menu toggle    # also: open, close
//
// This Item is never shown; it only groups the IPC handler, the capture
// process and the menu's own PanelWindow under one root.
Item {
    id: app

    property bool opened: false
    property string snapshotPath: ""
    readonly property string monitor: Hyprland.focusedMonitor?.name ?? ""

    function openMenu() {
        if (app.opened)
            return;
        menu.reset();
        // Clearing the backdrop releases the previous capture; a fresh unique
        // path then keeps Qt from ever handing back a cached older frame.
        menu.backdrop = "";
        app.snapshotPath = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-session-menu-" + Date.now() + ".ppm";
        app.opened = true;
        capture.running = true;
    }
    function closeMenu() {
        app.opened = false;
        capture.running = false;
        menu.backdrop = "";
    }
    function releaseSnapshot() {
        if (!app.snapshotPath)
            return;
        Quickshell.execDetached(["rm", "-f", app.snapshotPath]);
        app.snapshotPath = "";
    }

    IpcHandler {
        target: "menu"
        function open(): void {
            app.openMenu();
        }
        function close(): void {
            app.closeMenu();
        }
        function toggle(): void {
            if (app.opened)
                app.closeMenu();
            else
                app.openMenu();
        }
    }

    Process {
        id: capture
        // Raw PPM straight into tmpfs: no PNG encode, no base64, no data URL.
        // A 4K frame becomes a memcpy into RAM and a trivial decode, which is
        // the difference between the reveal starting now and a second from now.
        // The window is still unmapped while this runs, so it cannot photograph
        // the menu, and there is no unpainted surface to flash black either.
        command: ["sh", "-c", 'if [ -n "$1" ]; then grim -t ppm -o "$1" "$2"; else grim -t ppm "$2"; fi', "session-capture", app.monitor, app.snapshotPath]
        onExited: (code, status) => {
            // A capture that lands after the menu gave up would pop in mid
            // reveal, so it is dropped rather than shown late.
            if (app.opened && !menu.armed && code === 0 && status === 0)
                menu.backdrop = "file://" + app.snapshotPath;
            else
                app.releaseSnapshot();
        }
    }
    Connections {
        target: menu
        // The reveal drops the backdrop when it ends; the file goes with it.
        function onBackdropChanged() {
            if (menu.backdrop === "")
                app.releaseSnapshot();
        }
    }

    PanelWindow {
        id: window
        // Mapped only once there is a frame to show. The first frame is the
        // undistorted capture, identical to what is already on screen.
        visible: app.opened && menu.armed
        screen: Quickshell.screens.find(s => s.name === app.monitor) || Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-session-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        OrbitMenu {
            id: menu
            presenting: app.opened
            anchors.fill: parent
            busy: actionProcess.running
            onDismissed: app.closeMenu()
            onActionRequested: action => {
                if (action === "lock") {
                    // Drop the overlay before the locker takes the screen.
                    app.closeMenu();
                    Quickshell.execDetached(["hyprlock"]);
                    return;
                }
                const commands = {
                    exit: ["hyprctl", "dispatch", "exit"],
                    reboot: ["systemctl", "reboot"],
                    shutdown: ["systemctl", "poweroff"],
                    suspend: ["sh", "-c", "loginctl lock-session && systemctl suspend"],
                    hibernate: ["sh", "-c", "loginctl lock-session && systemctl hibernate"]
                };
                if (!commands[action])
                    return;
                actionProcess.command = commands[action];
                actionProcess.running = true;
            }
        }
        Process {
            id: actionProcess
            onExited: (code, status) => {
                if (code === 0 && status === 0)
                    app.closeMenu();
                else
                    menu.error = "Action failed. Try again or press Escape.";
            }
        }
    }
}
