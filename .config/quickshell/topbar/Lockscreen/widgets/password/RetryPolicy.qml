import QtQuick

Item {
    id: root

    property int attemptLimit: 3
    property int timeoutMinutes: 5
    property int failedAttempts: 0
    property int remainingSeconds: 0
    readonly property bool blocked: remainingSeconds > 0
    signal released

    function recordFailure() {
        failedAttempts++;
        if (failedAttempts >= attemptLimit) {
            remainingSeconds = timeoutMinutes * 60;
            countdown.start();
        }
    }

    function reset() {
        countdown.stop();
        failedAttempts = 0;
        remainingSeconds = 0;
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.remainingSeconds = Math.max(0, root.remainingSeconds - 1);
            if (!root.remainingSeconds) {
                root.reset();
                root.released();
            }
        }
    }
}
