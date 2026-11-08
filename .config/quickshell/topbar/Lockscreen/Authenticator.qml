import QtQuick
import Quickshell.Services.Pam

Item {
    id: root

    readonly property bool ready: enabled && pam.active && pam.responseRequired && !retry.running
    readonly property bool busy: enabled && !ready
    property string error: ""
    property string message: ""

    signal authenticated
    signal clearInput

    function begin() {
        if (!enabled || pam.active)
            return;

        message = "";
        if (!pam.start())
            error = "Authentication could not start. Try again.";
    }

    function respond(response) {
        if (!ready)
            return;

        error = "";
        pam.respond(response);
        clearInput();
    }

    onEnabledChanged: {
        clearInput();
        if (enabled) {
            begin();
        } else {
            retry.stop();
            pam.abort();
            error = "";
            message = "";
        }
    }

    Component.onCompleted: if (enabled)
        begin()

    PamContext {
        id: pam

        config: "login"
        onPamMessage: root.message = message
        onCompleted: result => {
            root.message = "";
            root.clearInput();
            if (!root.enabled)
                return;

            if (result === PamResult.Success) {
                root.authenticated();
            } else {
                root.error = result === PamResult.Error ? "Authentication unavailable. Try again." : "Authentication failed. Try again.";
                retry.restart();
            }
        }
    }

    Timer {
        id: retry

        interval: 1500
        onTriggered: root.begin()
    }
}
