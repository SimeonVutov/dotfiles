import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import qs.Common
import qs.Services

ColumnLayout {
    id: root
    property bool active: false
    readonly property bool wifi: !!Connectivity.passwordNetwork
    readonly property var prompt: Connectivity.bluetoothPrompt
    readonly property bool inputNeeded: wifi || (prompt && (prompt.kind === "pin" || prompt.kind === "passkey"))
    readonly property bool validInput: !inputNeeded || (prompt && prompt.kind === "passkey" ? /^[0-9]{1,6}$/.test(field.text) : field.text.length > 0)
    spacing: 16
    function cancel() {
        field.clear();
        if (wifi) Connectivity.passwordNetwork = null;
        else Connectivity.cancelBluetooth();
    }
    function submit() {
        if (!validInput) return;
        const value = field.text;
        field.clear();
        if (wifi) Connectivity.submitPassword(value);
        else Connectivity.answerBluetooth(value);
    }
    onActiveChanged: {
        field.clear();
        if (active && inputNeeded) field.forceActiveFocus();
    }
    onPromptChanged: field.clear()
    BarText {
        Layout.fillWidth: true
        text: root.wifi ? "Connect to Wi-Fi" : "Bluetooth pairing"
        font.pixelSize: 18
        font.bold: true
    }
    BarText {
        Layout.fillWidth: true
        text: root.wifi ? Connectivity.passwordNetwork.name : Connectivity.bluetoothName
        font.pixelSize: 14
        elide: Text.ElideRight
    }
    BarText {
        Layout.fillWidth: true
        text: root.wifi ? "Enter the network password." : root.prompt ? root.prompt.message : "Waiting for device…"
        color: Theme.popupSubtleText
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    TextField {
        id: field
        Layout.fillWidth: true
        implicitHeight: 44
        visible: root.inputNeeded
        echoMode: root.wifi ? TextInput.Password : TextInput.Normal
        maximumLength: root.wifi ? 128 : root.prompt && root.prompt.kind === "passkey" ? 6 : 16
        inputMethodHints: root.wifi ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
        color: Theme.popupText
        font.family: Theme.fontFamily
        font.pixelSize: 14
        placeholderText: root.wifi ? "Password" : "Pairing code"
        background: Rectangle { radius: 10; color: Theme.popupSurface; border.color: field.activeFocus ? Theme.popupSubtleText : Theme.popupBorder }
        onAccepted: root.submit()
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        ConnectionButton { text: "Cancel"; onClicked: root.cancel() }
        ConnectionButton {
            text: root.wifi ? "Connect" : "Confirm"
            checked: true
            visible: root.wifi || !root.prompt || root.prompt.kind !== "display"
            enabled: root.validInput
            onClicked: root.submit()
        }
    }
    Item { Layout.fillHeight: true }
}
