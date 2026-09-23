pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import qs.Common

PopupPanel {
    id: root

    property string moduleId: ""
    property Item moduleAnchor: null
    readonly property Item barAnchor: moduleAnchor && moduleAnchor.Window.window ? moduleAnchor.Window.window.contentItem : null
    property real frozenOffsetX: 0
    readonly property var definition: Config.moduleViews[moduleId] || ({})
    readonly property var selection: ModuleViewState.selection(moduleId)

    anchorItem: barAnchor || moduleAnchor
    anchorOffsetX: barAnchor ? frozenOffsetX : moduleAnchor ? Math.round((moduleAnchor.width - panelWidth) / 2) : 0
    panelWidth: 248
    contentPadding: 8
    panelHeight: contentColumn.implicitHeight + contentPadding * 2
    plainReveal: true

    Component.onCompleted: {
        if (barAnchor)
            frozenOffsetX = moduleAnchor.mapToItem(barAnchor, (moduleAnchor.width - panelWidth) / 2, 0).x;
    }

    ColumnLayout {
        id: contentColumn

        Layout.fillWidth: true
        spacing: 2

        Repeater {
            model: root.definition.items || []

            Rectangle {
                id: option

                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: option.modelData.description ? 50 : 38
                radius: 9
                color: optionMouse.containsMouse ? Theme.popupSurface : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                readonly property bool selected: root.definition.multiple
                    ? Array.isArray(root.selection) && root.selection.includes(modelData.value)
                    : root.selection === modelData.value
                readonly property bool requiredChoice: root.definition.required?.includes(modelData.value) || false

                BarText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 10
                    anchors.rightMargin: 32
                    anchors.topMargin: option.modelData.description ? 7 : 0
                    text: (option.modelData.icon ? option.modelData.icon + "   " : "") + option.modelData.label
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeLabel
                    elide: Text.ElideRight
                    height: option.modelData.description ? 19 : parent.height
                }

                BarText {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 10
                    anchors.rightMargin: 32
                    anchors.bottomMargin: 6
                    visible: !!option.modelData.description
                    text: option.modelData.description || ""
                    color: Theme.popupSubtleText
                    font.pixelSize: Theme.fontSizeCaption
                    elide: Text.ElideRight
                }

                BarText {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: option.selected ? Icons.check : ""
                    color: Theme.popupText
                    font.pixelSize: Theme.fontSizeSmall
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    enabled: !option.requiredChoice
                    hoverEnabled: true
                    cursorShape: option.requiredChoice ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (root.definition.multiple)
                            ModuleViewState.toggleItem(root.moduleId, option.modelData.value);
                        else {
                            ModuleViewState.setChoice(root.moduleId, option.modelData.value);
                            root.close();
                        }
                    }
                }
            }
        }

    }
}
