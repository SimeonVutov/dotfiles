import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common

ConnectionButton {
    id: root

    property color value: "#ffffff"
    property color draft: value
    property real hue: 0
    property real saturation: 0
    property real brightness: 1
    signal previewed(string color)
    signal edited(string color)
    signal cancelled

    implicitHeight: 38
    onClicked: picker.open()

    function byte(value) {
        const number = Math.round(value * 255);
        return number.toString(16).padStart(2, "0");
    }

    function hex(color) {
        const rgb = byte(color.r) + byte(color.g) + byte(color.b);
        return "#" + rgb + (color.a < 1 ? byte(color.a) : "");
    }

    function stored(color) {
        const rgb = byte(color.r) + byte(color.g) + byte(color.b);
        return "#" + (color.a < 1 ? byte(color.a) : "") + rgb;
    }

    function change(color) {
        // Keep the last hue and saturation at black, where RGB loses them.
        if (color.hsvHue >= 0)
            hue = color.hsvHue;

        if (color.hsvValue > 0)
            saturation = color.hsvSaturation;

        brightness = color.hsvValue;
        draft = color;
        hexInput.text = hex(color);
        previewed(stored(color));
    }

    function setHsv(nextHue, nextSaturation, nextBrightness) {
        hue = nextHue;
        saturation = nextSaturation;
        brightness = nextBrightness;
        change(Qt.hsva(hue, saturation, brightness, draft.a));
    }

    function setChannel(channel, value) {
        const values = [draft.r, draft.g, draft.b, draft.a];
        values[channel] = value / 255;
        change(Qt.rgba(values[0], values[1], values[2], values[3]));
    }

    contentItem: RowLayout {
        spacing: 10

        Rectangle {
            width: 20
            height: 20
            radius: 5
            color: root.value
            border.color: Theme.popupBorder
        }

        BarText {
            Layout.fillWidth: true
            text: root.hex(root.value)
            font.pixelSize: Theme.fontSizeCaption
            color: Theme.popupText
        }
    }

    Popup {
        id: picker

        property bool confirmed: false
        parent: Overlay.overlay
        width: 300
        padding: 16
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: Math.max(12, Math.min(root.mapToItem(parent, 0, 0).x, parent.width - width - 12))
        y: Math.max(12, Math.min(root.mapToItem(parent, 0, root.height).y, parent.height - height - 12))

        onAboutToShow: {
            confirmed = false;
            root.change(root.value);
        }

        onClosed: {
            if (!confirmed)
                root.cancelled();
        }

        background: Rectangle {
            radius: Theme.popupRadius
            color: Theme.popupBackground
            border.color: Theme.overlayBorderBright
        }

        contentItem: ColumnLayout {
            spacing: 12

            ColorWheel {
                Layout.alignment: Qt.AlignHCenter
                hue: root.hue
                saturation: root.saturation
                brightness: root.brightness
                onPicked: (hue, saturation) => root.setHsv(hue, saturation, root.brightness)
            }

            BarText {
                text: "Brightness"
                font.pixelSize: Theme.fontSizeCaption
                color: Theme.popupSubtleText
            }

            Slider {
                id: brightnessControl

                Layout.fillWidth: true
                from: 0
                to: 1
                value: root.brightness
                live: true
                onMoved: root.setHsv(root.hue, root.saturation, value)

                background: Rectangle {
                    x: brightnessControl.leftPadding
                    y: (brightnessControl.height - height) / 2
                    width: brightnessControl.availableWidth
                    height: 10
                    radius: 5
                    border.color: Theme.popupBorder
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "#000000"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.hsva(root.hue, root.saturation, 1, 1)
                        }
                    }
                }

                handle: Rectangle {
                    x: brightnessControl.leftPadding + brightnessControl.visualPosition * (brightnessControl.availableWidth - width)
                    y: (brightnessControl.height - height) / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: Qt.hsva(root.hue, root.saturation, root.brightness, 1)
                    border.width: 2
                    border.color: Theme.popupText
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                uniformCellWidths: true
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: ["R", "G", "B", "A"]

                    delegate: ColumnLayout {
                        id: channel

                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: 6

                        BarText {
                            text: channel.modelData
                            color: Theme.popupSubtleText
                            font.pixelSize: Theme.fontSizeCaption
                        }

                        TextField {
                            Layout.fillWidth: true
                            implicitWidth: 100
                            implicitHeight: 36
                            text: String(Math.round([root.draft.r, root.draft.g, root.draft.b, root.draft.a][channel.index] * 255))
                            color: Theme.popupText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: TextInput.AlignHCenter
                            selectByMouse: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator {
                                bottom: 0
                                top: 255
                            }

                            onTextEdited: {
                                if (acceptableInput)
                                    root.setChannel(channel.index, Number(text));
                            }

                            background: Rectangle {
                                radius: 8
                                color: Theme.popupSurface
                                border.color: parent.activeFocus ? Theme.overlayBorderBright : Theme.popupBorder
                            }
                        }
                    }
                }
            }

            TextField {
                id: hexInput

                Layout.fillWidth: true
                color: Theme.popupText
                font.family: Theme.fontFamily
                selectByMouse: true
                placeholderText: "#RRGGBB or #RRGGBBAA"
                validator: RegularExpressionValidator {
                    regularExpression: /#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})/
                }
                background: Rectangle {
                    radius: 8
                    color: Theme.popupSurface
                    border.color: Theme.popupBorder
                }

                onTextEdited: {
                    if (!acceptableInput)
                        return;

                    const digits = text.slice(1);
                    const color = digits.length === 8 ? "#" + digits.slice(6) + digits.slice(0, 6) : text;
                    root.change(Qt.color(color));
                }
            }

            RowLayout {
                Layout.fillWidth: true

                ConnectionButton {
                    text: "Cancel"
                    onClicked: picker.close()
                }

                Item {
                    Layout.fillWidth: true
                }

                ConnectionButton {
                    text: "Apply"
                    checked: true
                    enabled: hexInput.acceptableInput
                    onClicked: {
                        const color = root.stored(root.draft);
                        picker.confirmed = true;
                        picker.close();
                        root.edited(color);
                    }
                }
            }
        }
    }
}
