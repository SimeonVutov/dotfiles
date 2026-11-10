import QtQuick
import Quickshell

ShellRoot {
    id: root

    property int step: 0
    property int ticks: 0
    property int successes: 0
    property int cleared: 0

    Authenticator {
        id: authentication
        enabled: false
        onAuthenticated: root.successes++
        onClearInput: root.cleared++
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            root.ticks++;
            if (root.ticks > 100)
                throw new Error("Authentication state test timed out");

            if (root.step === 0) {
                authentication.respond("test-success");
                if (root.successes !== 0)
                    throw new Error("Inactive authentication accepted a response");

                authentication.enabled = true;
                root.step++;
            } else if (root.step === 1 && authentication.ready) {
                authentication.respond("test-failure");
                if (root.successes || !authentication.error || authentication.ready)
                    throw new Error("Failure did not reject and throttle authentication");

                root.step++;
            } else if (root.step === 2 && authentication.ready) {
                authentication.respond("test-success");
                if (root.successes !== 1 || root.cleared < 2)
                    throw new Error("Successful authentication or input clearing failed");

                authentication.enabled = false;
                authentication.respond("test-success");
                if (root.successes !== 1)
                    throw new Error("Disabled authentication emitted success");

                console.log("PASS PAM prompt lifecycle, failure throttling, success gating, and input clearing");
                Qt.quit();
            }
        }
    }
}
