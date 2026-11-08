import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Ui

RowLayout {
    id: root

    required property var store
    property string stateName: "idle"
    spacing: 8
    opacity: stateName === "idle" ? 0 : 1

    Connections {
        target: root.store

        function onSavingChanged() {
            if (root.store.saving)
                root.stateName = "saving";
        }

        function onSaved() {
            root.stateName = "saved";
        }

        function onSaveFailed() {
            root.stateName = "error";
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFast
        }
    }

    Item {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18

        Canvas {
            anchors.fill: parent
            visible: root.stateName === "saving"

            onPaint: {
                const context = getContext("2d");
                context.reset();
                context.lineWidth = 2;
                context.lineCap = "round";
                context.strokeStyle = "#343434";
                context.beginPath();
                context.arc(9, 9, 7, 0, Math.PI * 2);
                context.stroke();
                context.strokeStyle = "#eeeeee";
                context.beginPath();
                context.arc(9, 9, 7, 0, Math.PI * 1.35);
                context.stroke();
            }

            RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 850
                loops: Animation.Infinite
                running: root.stateName === "saving"
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.stateName !== "saving"
            text: root.stateName === "error" ? "!" : "✓"
            color: root.stateName === "error" ? Theme.criticalBackground : Theme.popupText
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }
    }

    BarText {
        text: root.stateName === "saving" ? "Saving…" : root.stateName === "error" ? "Not saved" : "Saved"
        color: root.stateName === "error" ? Theme.criticalBackground : Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }
}
