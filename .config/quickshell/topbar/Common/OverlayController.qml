pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property string owner: ""
    property string pendingOwner: ""

    signal closeRequested(string owner)
    signal granted(string owner)

    // The app launcher is a process of its own, so it cannot take part in the
    // arbitration below: an overlay of this process asks it to close instead.
    function closeLauncher() {
        Quickshell.execDetached(["qs", "ipc", "-n", "-c", "launcher", "call", "launcher", "close"]);
    }

    // Closes whatever overlay of this process is open, so that the launcher
    // can take the screen.
    function dismiss() {
        if (owner)
            closeRequested(owner);
    }

    function request(candidate) {
        closeLauncher();
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
