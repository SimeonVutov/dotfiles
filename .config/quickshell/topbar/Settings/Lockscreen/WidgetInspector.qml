import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common
import qs.Ui
import "../../Lockscreen/WidgetCatalog.js" as Catalog

ScrollView {
    id: root

    required property var controller
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: root.availableWidth
        spacing: 12

        BarText {
            text: "Placed widgets"
            color: Theme.popupSubtleText
        }

        Repeater {
            model: root.controller.layout.widgets

            delegate: Rectangle {
                id: card

                required property var modelData
                readonly property var definition: Catalog.find(modelData.type)
                readonly property bool expanded: root.controller.selected === modelData.id

                Layout.fillWidth: true
                implicitHeight: contents.implicitHeight + 24
                radius: 12
                color: cardHover.hovered ? Theme.popupBorder : Theme.popupSurface
                border.color: expanded ? Theme.overlayBorderBright : Theme.popupBorder

                HoverHandler {
                    id: cardHover
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                ColumnLayout {
                    id: contents

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 12
                    }
                    spacing: 12

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 34

                        BarText {
                            anchors.left: disclosure.right
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.definition.name
                            color: Theme.popupText
                        }

                        BarText {
                            id: disclosure

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.chevronDown
                            rotation: card.expanded ? 0 : -90
                            color: Theme.popupSubtleText
                            font.pixelSize: 11

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: Theme.durationFast
                                }
                            }
                        }

                        IconButton {
                            id: removeWidget

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            icon: Icons.trash
                            visible: card.expanded && !card.definition.required
                            enabled: root.controller.ready
                            onClicked: root.controller.removeWidget(card.modelData.id)
                            ToolTip.visible: containsMouse
                            ToolTip.text: "Remove widget"
                        }

                        MouseArea {
                            anchors {
                                left: parent.left
                                right: removeWidget.visible ? removeWidget.left : parent.right
                                top: parent.top
                                bottom: parent.bottom
                            }
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controller.selected = card.expanded ? "" : card.modelData.id
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: card.expanded
                        enabled: root.controller.ready
                        spacing: 12

                        RowLayout {
                            SettingsChoice {
                                Layout.fillWidth: true
                                label: "Width"
                                model: Array.from({
                                    length: root.controller.layout.columns
                                }, (_, index) => String(index + 1))
                                currentIndex: card.modelData.columns - 1
                                onChosen: index => root.controller.updateWidget(card.modelData.id, {
                                        columns: index + 1
                                    })
                            }

                            SettingsChoice {
                                Layout.fillWidth: true
                                label: "Height"
                                model: Array.from({
                                    length: root.controller.layout.rows
                                }, (_, index) => String(index + 1))
                                currentIndex: card.modelData.rows - 1
                                onChosen: index => root.controller.updateWidget(card.modelData.id, {
                                        rows: index + 1
                                    })
                            }
                        }

                        Repeater {
                            model: Catalog.controls(card.modelData.type)

                            delegate: ColumnLayout {
                                id: setting

                                required property var modelData
                                readonly property var current: card.modelData.settings[modelData.key] ?? modelData.initial

                                Layout.fillWidth: true
                                spacing: 5

                                BarText {
                                    text: setting.modelData.label
                                    color: Theme.popupSubtleText
                                    font.pixelSize: Theme.fontSizeCaption
                                }

                                Loader {
                                    Layout.fillWidth: true
                                    sourceComponent: setting.modelData.kind === "number" ? numericControl : colorControl
                                }

                                Component {
                                    id: numericControl

                                    Slider {
                                        property bool cancelling: false

                                        from: setting.modelData.minimum
                                        to: setting.modelData.maximum
                                        stepSize: setting.modelData.step
                                        value: setting.current
                                        onPressedChanged: {
                                            if (pressed)
                                                return;

                                            if (cancelling) {
                                                cancelling = false;
                                                value = Qt.binding(() => setting.current);
                                            } else {
                                                root.controller.updateSetting(card.modelData.id, setting.modelData.key, value);
                                            }
                                        }

                                        onMoved: if (!pressed)
                                            root.controller.updateSetting(card.modelData.id, setting.modelData.key, value)

                                        Keys.onEscapePressed: event => {
                                            cancelling = pressed;
                                            value = Qt.binding(() => setting.current);
                                            root.forceActiveFocus();
                                            event.accepted = true;
                                        }
                                    }
                                }

                                Component {
                                    id: colorControl

                                    TextField {
                                        text: setting.current
                                        color: Theme.popupText
                                        placeholderText: "#ffffff"
                                        selectByMouse: true
                                        background: Rectangle {
                                            color: Theme.popupBackground
                                            radius: 6
                                            border.color: Theme.popupBorder
                                        }
                                        onEditingFinished: if (text !== setting.current)
                                            root.controller.updateSetting(card.modelData.id, setting.modelData.key, text)

                                        Keys.onEscapePressed: event => {
                                            text = setting.current;
                                            root.forceActiveFocus();
                                            event.accepted = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
