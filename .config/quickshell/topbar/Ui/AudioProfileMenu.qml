pragma ComponentBehavior: Bound

import QtQuick
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
                    font.pixelSize: 15
                    font.bold: true
                }
                BarText {
                    width: parent.width
                    text: root.deviceName
                    color: Theme.popupSubtleText
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                id: closeButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                radius: 14
                color: closeMouse.containsMouse ? Theme.popupBorder : Theme.popupSurface

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }

                IconButton {
                    id: closeMouse
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    size: 12
                    icon: Icons.close
                    onClicked: root.dismissed()
                }
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

            ScrollBar.vertical: ScrollBar {
                id: scrollIndicator
                policy: ScrollBar.AsNeeded
                width: 3
                contentItem: Rectangle {
                    radius: width / 2
                    color: Theme.popupSubtleText
                    opacity: scrollIndicator.active ? 0.8 : 0.35
                }
                background: Item {}
            }

            delegate: AudioChoiceRow {
                required property var modelData

                width: profilesView.width - (profilesView.contentHeight > profilesView.height ? 9 : 0)
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
            font.pixelSize: 12
        }
    }
}
