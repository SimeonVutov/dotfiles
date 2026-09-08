import QtQuick
import QtQuick.Effects
import qs.Common

// Album art with properly rounded corners, plus a placeholder for when there's
// no art (or it fails to load — browsers hand out URLs that go stale).
Item {
    id: root

    property string source: ""
    property int radius: 12

    readonly property bool hasArt: source !== "" && image.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.popupSurface
        visible: !root.hasArt

        Text {
            anchors.centerIn: parent
            text: Icons.music
            color: Theme.popupSubtleText
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(parent.height * 0.38)
            textFormat: Text.PlainText
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: false
        sourceSize.width: Math.round(root.width * 2)
        sourceSize.height: Math.round(root.height * 2)
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: root.radius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        visible: root.hasArt

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationNormal
                easing.type: Theme.easing
            }
        }
    }
}
