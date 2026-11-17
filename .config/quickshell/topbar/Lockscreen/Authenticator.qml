import QtQuick
import Quickshell.Services.Pam
import "widgets/password"

Item {
    id: root

    property bool checking: false
    readonly property bool ready: enabled && pam.active && pam.responseRequired && !checking && !retry.running && !policy.blocked
    readonly property bool busy: enabled && !ready
    readonly property bool coolingDown: policy.blocked
    property int attemptLimit: 3
    property int timeoutMinutes: 5
    property string lastError: ""
    readonly property string error: policy.blocked ? "Try again in " + Math.floor(policy.remainingSeconds / 60) + ":" + String(policy.remainingSeconds % 60).padStart(2, "0") : lastError
    property string message: ""

    signal rejected
    signal authenticated
    signal clearInput

    function begin() {
        if (!enabled || pam.active || policy.blocked)
            return;

        message = "";
        if (!pam.start())
            lastError = "Authentication could not start. Try again.";
    }

    function respond(response) {
        if (!ready)
            return;

        lastError = "";
        checking = true;
        pam.respond(response);
        clearInput();
    }

    onEnabledChanged: {
        clearInput();
        if (enabled) {
            begin();
        } else {
            checking = false;
            retry.stop();
            pam.abort();
            lastError = "";
            message = "";
        }
    }

    Component.onCompleted: if (enabled)
        begin()

    RetryPolicy {
        id: policy
        attemptLimit: Math.max(1, root.attemptLimit)
        timeoutMinutes: Math.max(1, root.timeoutMinutes)
        onReleased: root.begin()
    }

    PamContext {
        id: pam

        config: "login"
        onPamMessage: {
            root.message = message;
            if (responseRequired)
                root.checking = false;
        }
        onCompleted: result => {
            root.checking = false;
            root.message = "";
            root.clearInput();
            if (!root.enabled)
                return;

            if (result === PamResult.Success) {
                policy.reset();
                root.authenticated();
            } else {
                root.lastError = result === PamResult.Error ? "Authentication unavailable. Try again." : "Wrong password";
                if (result === PamResult.Failed || result === PamResult.MaxTries) {
                    policy.recordFailure();
                    root.rejected();
                }
                retry.restart();
            }
        }
    }

    Timer {
        id: retry

        interval: 2000
        onTriggered: {
            root.lastError = "";
            root.begin();
        }
    }
}
