pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property string owner: ""
    property string pendingOwner: ""

    signal closeRequested(string owner)
    signal granted(string owner)

    function request(candidate) {
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
