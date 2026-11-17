import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common
import qs.Ui
import "../../Lockscreen/Animations.js" as Animations

RowLayout {
    id: root

    required property var controller
    enabled: controller.ready && !controller.moving
    spacing: 8

    BarText {
        text: "Animation"
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    SettingsChoice {
        Layout.preferredWidth: 130
        model: Animations.options.map(option => option.name)
        currentIndex: Animations.options.findIndex(option => option.type === root.controller.layout.animation.type)

        onChosen: index => {
            root.controller.updateAnimation({
                type: Animations.options[index].type
            });
            currentIndex = Qt.binding(() => Animations.options.findIndex(option => option.type === root.controller.layout.animation.type));
        }
    }

    BarText {
        visible: duration.visible
        text: "Duration"
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }

    TextField {
        id: duration

        Layout.preferredWidth: 66
        implicitHeight: 38
        visible: root.controller.layout.animation.type !== "none"
        text: String(root.controller.layout.animation.duration / 1000)
        color: acceptableInput ? Theme.popupText : Theme.criticalBackground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        horizontalAlignment: TextInput.AlignHCenter
        selectByMouse: true
        inputMethodHints: Qt.ImhFormattedNumbersOnly

        validator: DoubleValidator {
            bottom: .05
            top: 10
            decimals: 2
            notation: DoubleValidator.StandardNotation
            locale: "C"
        }

        onEditingFinished: {
            if (acceptableInput)
                root.controller.updateAnimation({
                    duration: Math.round(Number(text) * 1000)
                });

            text = Qt.binding(() => String(root.controller.layout.animation.duration / 1000));
        }

        Keys.onEscapePressed: event => {
            text = Qt.binding(() => String(root.controller.layout.animation.duration / 1000));
            root.forceActiveFocus();
            event.accepted = true;
        }

        background: Rectangle {
            radius: 9
            color: Theme.popupSurface
            border.color: duration.activeFocus ? Theme.popupText : Theme.popupBorder
        }
    }

    BarText {
        visible: duration.visible
        text: "s"
        color: Theme.popupSubtleText
        font.pixelSize: Theme.fontSizeCaption
    }
}
