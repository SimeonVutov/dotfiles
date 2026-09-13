pragma ComponentBehavior: Bound

import QtQuick
import qs.Ui
import QtQuick.Controls.Basic
import QtQuick.Layouts
import qs.Common
import qs.Services

Item {
    id: root

    required property int cardId
    required property string deviceName
    readonly property var card: AudioDevices.cardById(cardId)
    readonly property var profiles: AudioDevices.profilesForCard(card)
    signal dismissed

    onVisibleChanged: if (visible)
        profilesView.contentY = 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            Layout.fillWidth: true
            implicitHeight: 42

            Column {
                anchors.left: parent.left
                anchors.right: closeButton.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                BarText {
                    width: parent.width
                    text: "Device profiles"
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                BarText {
                    width: parent.width
                    text: root.deviceName
                    color: Theme.popupSubtleText
                    font.pixelSize: Theme.fontSizeTiny
                    elide: Text.ElideRight
                }
            }

            CloseButton {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.dismissed()
            }
        }

        ListView {
            id: profilesView

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 3
            model: root.profiles
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ThinScrollBar {
                id: scrollIndicator
            }

            delegate: AudioChoiceRow {
                required property var modelData

                width: profilesView.width - (profilesView.contentHeight > profilesView.height ? scrollIndicator.gutter : 0)
                implicitHeight: 52
                title: modelData.description
                subtitle: modelData.name + (modelData.available === "no" ? " · Unavailable" : "")
                selected: !!root.card && root.card.activeProfile === modelData.name
                busy: AudioDevices.profileBusy || modelData.available === "no"
                onChosen: AudioDevices.setProfile(root.card, modelData)
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: root.profiles.length === 0
            text: AudioDevices.profileBusy ? "Loading device profiles…" : "No selectable profiles for this device."
            color: Theme.popupSubtleText
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeCaption
        }
    }
}
