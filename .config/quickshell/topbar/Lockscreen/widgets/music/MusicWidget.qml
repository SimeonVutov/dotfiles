pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.Ui
import qs.Ui.Media
import qs.Core.Media
import "../.."

Widget {
    id: root

    readonly property alias player: playback

    Player {
        id: playback
    }

    widgetType: "music"
    designWidth: Math.max(320, width)
    designHeight: Math.max(440, height)
    property bool watchingPosition: false
    readonly property bool needsPosition: visible && root.player.length > 0

    function updatePositionWatch() {
        if (watchingPosition === needsPosition)
            return;

        root.player.watchPosition(needsPosition);
        watchingPosition = needsPosition;
    }

    onNeedsPositionChanged: updatePositionWatch()
    Component.onCompleted: updatePositionWatch()
    Component.onDestruction: {
        if (watchingPosition)
            root.player.watchPosition(false);
    }

    Column {
        id: presentation

        anchors.centerIn: parent
        width: Math.min(420, parent.width - 32)
        spacing: 12
        readonly property real coverSize: Math.min(width, root.settings.artworkSize,
            root.designHeight - heading.height - controls.height
            - (timeline.visible ? timeline.height + spacing : 0) - 24 - spacing * 2)

        Column {
            id: heading
            width: parent.width
            spacing: 5

            Text {
                width: parent.width
                text: root.player.title || "Nothing playing"
                color: root.settings.textColor
                font.family: Theme.fontFamily
                font.pixelSize: root.settings.titleSize
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                text: root.player.artist || root.player.identity
                visible: text.length > 0
                color: root.settings.textColor
                opacity: .75
                font.family: Theme.fontFamily
                font.pixelSize: 15
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }

        AlbumArt {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(36, presentation.coverSize)
            height: width
            radius: Math.min(18, root.settings.cornerRadius)
            source: root.visible ? root.player.artUrl : ""
        }

        Item {
            id: timeline
            width: parent.width
            height: 42
            visible: root.player.length > 0

            SeekBar {
                anchors.left: parent.left
                anchors.right: parent.right
                player: root.player
                height: 22
                trackHeight: 4
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: root.player.formatTime(root.player.position)
                color: root.settings.textColor
                opacity: .75
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }

            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: root.player.formatTime(root.player.length)
                color: root.settings.textColor
                opacity: .75
                font.family: Theme.fontFamily
                font.pixelSize: 14
            }
        }

        MusicControls {
            id: controls
            anchors.horizontalCenter: parent.horizontalCenter
            width: implicitWidth
            height: implicitHeight
            player: root.player
            textColor: root.settings.textColor
        }
    }
}
