import QtQuick
import QtQuick.Controls.Basic
import Quickshell

FocusScope {
    id: root
    required property var controller
    property var widgetSettings: ({})
    readonly property color textColor: widgetSettings.textColor || controller.colors.text
    focus: true
    function unlock() {
        if (!root.controller.authenticator.ready || !password.text.length)
            return;

        root.controller.authenticator.respond(password.text);
        password.clear();
    }
    Component.onCompleted: password.forceActiveFocus()
    Connections {
        target: root.controller.authenticator
        function onClearInput() {
            password.clear();
            password.forceActiveFocus();
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 25
        scale: Math.min(1, root.height / 270, root.width / 340)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Hi, " + Quickshell.env("USER")
            color: root.textColor
            font.family: "SF Pro Display"
            font.bold: true
            font.pointSize: 25
        }
        TextField {
            id: password
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(300, root.width - 20)
            height: 60
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            horizontalAlignment: TextInput.AlignHCenter
            font.family: "SF Pro Display"
            font.pixelSize: 22
            color: root.textColor
            placeholderText: root.controller.authenticator.busy ? "Authenticating…" : "Enter password"
            placeholderTextColor: "#99ffffff"
            readOnly: !root.controller.authenticator.ready
            selectByMouse: false
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            background: Rectangle {
                radius: 10
                color: root.controller.colors.accent
                opacity: .85
                border.width: 2
                border.color: root.controller.authenticator.error ? "#dc7474" : "#505050"
            }
            onAccepted: root.unlock()
            Keys.onEscapePressed: clear()
        }
        Button {
            id: unlockButton

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(300, root.width - 20)
            height: 36
            text: "Unlock"
            enabled: root.controller.authenticator.ready && password.text.length > 0
            onClicked: root.unlock()

            contentItem: Text {
                text: unlockButton.text
                color: unlockButton.enabled ? "#ffffff" : "#888888"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: "SF Pro Display"
                font.pixelSize: 14
            }

            background: Rectangle {
                radius: 9
                color: unlockButton.down ? "#505050" : "#303030"
                border.color: unlockButton.activeFocus ? "#ffffff" : "#505050"
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(100, root.width - 16)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.controller.authenticator.error || root.controller.authenticator.message
            color: root.controller.authenticator.error ? "#e6a0a0" : "#cccccc"
            font.family: "SF Pro Display"
            font.pixelSize: 13
        }
    }
}
