import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common
import qs.Ui

ScrollView {
    id: root

    required property var controller
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: root.availableWidth
        spacing: 12

        Repeater {
            model: root.controller.available

            delegate: ConnectionButton {
                id: card

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 58
                text: modelData.name
                enabled: root.controller.ready
                onClicked: root.controller.beginNew(modelData.type)

                background: Rectangle {
                    radius: 12
                    color: card.hovered || card.down ? Theme.popupBorder : Theme.popupSurface
                    border.color: Theme.popupBorder

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durationFast
                        }
                    }
                }
            }
        }
    }
}
