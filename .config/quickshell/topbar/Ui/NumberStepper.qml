import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common

ColumnLayout {
    id: root

    property string label: ""
    property int value: 1
    property int minimum: 1
    property int maximum: 100
    signal edited(int value)
    spacing: 8

    function commit(next) {
        if (Number.isInteger(next) && next >= minimum && next <= maximum && next !== value)
            edited(next);

        // The saved model remains authoritative if a resize is rejected.
        input.text = Qt.binding(() => String(root.value));
    }

    BarText {
        text: root.label
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: 9
        color: Theme.popupSurface
        border.color: input.activeFocus ? Theme.popupText : Theme.popupBorder

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            ConnectionButton {
                implicitWidth: 26
                implicitHeight: 28
                text: "−"
                subtle: true
                enabled: root.value > root.minimum
                onClicked: root.commit(root.value - 1)
            }

            TextField {
                id: input

                Layout.fillWidth: true
                Layout.minimumWidth: 24
                implicitWidth: 32
                text: String(root.value)
                color: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: TextInput.AlignHCenter
                selectByMouse: true
                inputMethodHints: Qt.ImhDigitsOnly
                padding: 0
                background: null
                validator: IntValidator {
                    bottom: root.minimum
                    top: root.maximum
                }
                onEditingFinished: root.commit(Number(text))

                Keys.onEscapePressed: event => {
                    text = Qt.binding(() => String(root.value));
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }

            ConnectionButton {
                implicitWidth: 26
                implicitHeight: 28
                text: "+"
                subtle: true
                enabled: root.value < root.maximum
                onClicked: root.commit(root.value + 1)
            }
        }
    }
}
