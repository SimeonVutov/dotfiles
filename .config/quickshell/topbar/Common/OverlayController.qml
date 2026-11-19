pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property string owner: ""
    property string pendingOwner: ""

    signal closeRequested(string owner)
    signal granted(string owner)

    // Full-screen overlays that run as processes of their own (the app launcher,
    // the session menu and the wallpaper picker), by name. They cannot take part
    // in the arbitration below, so they announce themselves and an overlay of
    // this process asks them to close instead.
    property var externalOverlays: ({})

    // Whether anything covers the screen, in this process or another.
    readonly property bool active: owner !== "" || Object.keys(externalOverlays).length > 0

    function closeOverlayProcesses() {
        Quickshell.execDetached(["qs", "ipc", "-n", "-c", "launcher", "call", "launcher", "close"]);
        Quickshell.execDetached(["qs", "ipc", "-n", "-c", "sessionmenu", "call", "menu", "close"]);
        Quickshell.execDetached(["qs", "ipc", "-n", "-c", "wallpaper", "call", "wallpaper", "close"]);
    }

    // An overlay process opened: it takes the screen from this process's overlay.
    function beginExternal(name) {
        externalOverlays = Object.assign({}, externalOverlays, {[name]: true});
        if (owner)
            closeRequested(owner);
    }

    function endExternal(name) {
        const remaining = Object.assign({}, externalOverlays);
        delete remaining[name];
        externalOverlays = remaining;
    }

    function request(candidate) {
        closeOverlayProcesses();
        if (!owner || owner === candidate) {
            owner = candidate;
            return true;
        }

        pendingOwner = candidate;
        closeRequested(owner);
        return false;
    }

    function release(candidate) {
        if (owner !== candidate)
            return;

        owner = "";
        if (!pendingOwner)
            return;

        const nextOwner = pendingOwner;
        pendingOwner = "";
        owner = nextOwner;
        granted(nextOwner);
    }

    function cancel(candidate) {
        if (pendingOwner === candidate)
            pendingOwner = "";
    }
}
