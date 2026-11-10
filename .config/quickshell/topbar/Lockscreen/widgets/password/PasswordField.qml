import QtQuick
import QtQuick.Controls.Basic

FocusScope {
    id: root

    required property var authenticator
    property color accent: "#555555"
    property color textColor: "#ffffff"
    property real failureProgress: 0
    property real shakeOffset: 0
    property int submittedLength: 0

    transform: Translate {
        x: root.shakeOffset
    }

    implicitWidth: 300
    implicitHeight: 60

    function submit() {
        if (!authenticator.ready || !input.length)
            return;

        submittedLength = input.length;
        authenticator.respond(input.text);
        input.clear();
    }

    Component.onCompleted: input.forceActiveFocus()

    Connections {
        target: root.authenticator

        function onClearInput() {
            input.clear();
            input.forceActiveFocus();
        }

        function onRejected() {
            failure.restart();
        }

        function onCheckingChanged() {
            if (!root.authenticator.checking)
                root.submittedLength = 0;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.accent
        opacity: input.length || root.authenticator.busy || failure.running ? 1 : .3

        Behavior on opacity {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
    }

    FailureOutline {
        anchors.fill: parent
        active: failure.running
        progress: root.failureProgress
    }

    TextField {
        id: input
        anchors.fill: parent
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        color: "transparent"
        selectionColor: "transparent"
        cursorVisible: false
        cursorDelegate: Item {}
        readOnly: !root.authenticator.ready || failure.running
        horizontalAlignment: TextInput.AlignHCenter
        selectByMouse: false
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        background: null
        onAccepted: root.submit()
        Keys.onEscapePressed: clear()
    }

    PasswordDots {
        id: dots
        anchors.fill: parent
        count: root.authenticator.checking ? root.submittedLength : input.length
        color: root.textColor

        SequentialAnimation {
            running: root.authenticator.checking
            loops: Animation.Infinite
            onStopped: dots.opacity = 1

            NumberAnimation {
                target: dots
                property: "opacity"
                from: 1
                to: .35
                duration: 400
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: dots
                property: "opacity"
                from: .35
                to: 1
                duration: 400
                easing.type: Easing.InOutSine
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 24
        visible: input.length === 0
        text: failure.running ? "Wrong password" : root.authenticator.checking ? "" : root.authenticator.error || "Enter Password"
        color: failure.running || root.authenticator.error ? "#ff8290" : "#99ffffff"
        font.family: "SF Pro Display"
        font.italic: true
        font.pixelSize: 18
        minimumPixelSize: 12
        fontSizeMode: Text.Fit
        horizontalAlignment: Text.AlignHCenter
    }

    ParallelAnimation {
        id: failure

        NumberAnimation {
            target: root
            property: "failureProgress"
            from: 0
            to: 1
            duration: 2000
        }

        SequentialAnimation {
            NumberAnimation {
                target: root
                property: "shakeOffset"
                to: -8
                duration: 45
            }
            NumberAnimation {
                target: root
                property: "shakeOffset"
                to: 8
                duration: 70
            }
            NumberAnimation {
                target: root
                property: "shakeOffset"
                to: -6
                duration: 65
            }
            NumberAnimation {
                target: root
                property: "shakeOffset"
                to: 4
                duration: 60
            }
            NumberAnimation {
                target: root
                property: "shakeOffset"
                to: 0
                duration: 60
            }
        }
    }
}
