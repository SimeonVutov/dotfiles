pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Ui
import qs.Services

PopupPanel {
    id: root
    required property var receiver
    readonly property var message: receiver.current
    readonly property bool hasMessage: message !== null
    readonly property bool hasSender: !!message?.sender
    readonly property bool hasTitle: !!message?.title
    readonly property bool hasBody: !!message?.body
    readonly property bool hasImage: !!message?.image
    readonly property bool hasIcon: !!message?.icon
    readonly property bool hasMedia: hasImage || hasIcon
    readonly property bool hasHeaderIcon: hasImage && hasIcon && hasSender
    readonly property bool hasProgress: message?.progress !== undefined && message?.progress !== null
    readonly property var actions: message?.actions || []
    readonly property string url: firstUrl(message?.body || "")
    readonly property real textWidth: panelWidth - 2 * contentPadding - (hasMedia ? 78 : 0)
    readonly property real senderHeight: hasSender ? 17 : 0
    readonly property real titleHeight: hasTitle ? titleMeasure.implicitHeight : 0
    readonly property real bodyHeight: hasBody ? Math.min(150, bodyMeasure.implicitHeight) : 0
    readonly property real textHeight: senderHeight + (hasSender && (hasTitle || hasBody) ? 7 : 0) + titleHeight + (hasTitle && hasBody ? 6 : 0) + bodyHeight

    panelWidth: 380
    contentPadding: 18
    rowSpacing: 11
    animateHeight: true
    smoothAnchorMovement: true
    focusGrabEnabled: false
    onOpenChanged: {
        if (!open && receiver.phase !== "listening" && receiver.phase !== "closing")
            receiver.closeCurrent();
    }

    function firstUrl(text) {
        const match = text.match(/https?:\/\/[^\s<>"']+/i);
        return match ? match[0].replace(/[.,;!?)]*$/, "") : "";
    }

    function iconSource(icon) {
        if (!icon)
            return "";
        if (icon.startsWith("file:") || icon.startsWith("image:"))
            return icon;
        if (icon.startsWith("/"))
            return "file://" + icon;
        return Quickshell.iconPath(icon, true);
    }

    Text {
        id: titleMeasure
        visible: false
        width: root.textWidth
        text: root.message?.title || ""
        textFormat: Text.PlainText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    Text {
        id: bodyMeasure
        visible: false
        width: root.textWidth
        text: root.message?.body || ""
        textFormat: Text.StyledText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        lineHeight: 1.2
        wrapMode: Text.WordWrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: "Notifications"
            color: Theme.popupText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
        }
        Item {
            Layout.fillWidth: true
        }
        Text {
            visible: root.receiver.pendingCount > 0
            text: root.receiver.pendingCount + " queued"
            color: Theme.popupSubtleText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
        }
    }

    Item {
        visible: root.hasMessage
        opacity: root.receiver.contentOpacity
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? Math.max(root.textHeight, root.hasMedia ? 64 : 0) : 0

        Text {
            visible: root.hasSender
            x: root.hasHeaderIcon ? 22 : 0
            y: 0
            width: root.textWidth - x - (countLabel.visible ? countLabel.implicitWidth + 8 : 0)
            height: root.senderHeight
            text: root.message?.sender || ""
            textFormat: Text.PlainText
            color: root.message?.urgency === "critical" ? Theme.criticalBackground : Theme.popupSubtleText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeCaption
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Image {
            visible: root.hasHeaderIcon
            x: 0
            y: 0
            width: 16
            height: 16
            source: root.iconSource(root.message?.icon || "")
            fillMode: Image.PreserveAspectFit
        }
        Text {
            id: countLabel
            visible: (root.message?.count || 0) > 1
            x: root.textWidth - width
            y: 0
            text: "×" + (root.message?.count || 0)
            color: Theme.popupSubtleText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeTiny
        }
        Text {
            visible: root.hasTitle
            x: 0
            y: root.senderHeight + (root.hasSender ? 7 : 0)
            width: root.textWidth
            height: root.titleHeight
            text: root.receiver.typedTitle
            textFormat: Text.PlainText
            color: Theme.popupText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        Flickable {
            visible: root.hasBody
            x: 0
            y: root.senderHeight + (root.hasSender ? 7 : 0) + root.titleHeight + (root.hasTitle ? 6 : 0)
            width: root.textWidth
            height: root.bodyHeight
            clip: true
            contentHeight: bodyText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Text {
                id: bodyText
                width: parent.width
                text: root.receiver.typing ? root.receiver.typedBody : root.message?.body || ""
                textFormat: root.receiver.typing ? Text.PlainText : Text.StyledText
                color: Theme.popupSubtleText
                linkColor: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                lineHeight: 1.2
                wrapMode: Text.WordWrap
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
        Image {
            visible: root.hasMedia
            x: parent.width - width
            y: Math.max(0, (parent.height - height) / 2)
            width: root.hasImage ? 64 : 48
            height: width
            source: root.hasImage ? root.message.image : root.hasIcon ? root.iconSource(root.message.icon) : ""
            fillMode: Image.PreserveAspectFit
        }
    }

    Text {
        visible: !root.hasMessage
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        text: "No notifications yet"
        color: Theme.popupSubtleText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
    }

    ColumnLayout {
        visible: root.hasProgress
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Progress"
                color: Theme.popupSubtleText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: Math.round(Number(root.message?.progress || 0)) + "%"
                color: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.popupBorder
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, Number(root.message?.progress || 0))) / 100
                height: parent.height
                radius: 2
                color: Theme.popupAccent
            }
        }
    }

    Flow {
        visible: root.actions.length > 0 || root.url !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        spacing: 6
        Repeater {
            model: root.actions
            Rectangle {
                required property var modelData
                width: Math.min(120, actionText.implicitWidth + 22)
                height: 30
                radius: 9
                color: actionMouse.containsMouse ? Theme.overlaySurfaceHover : Theme.popupSurface
                border.color: Theme.popupBorder
                Text {
                    id: actionText
                    anchors.centerIn: parent
                    width: parent.width - 14
                    text: parent.modelData.text || "Action"
                    textFormat: Text.PlainText
                    color: Theme.popupText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeCaption
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: actionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.invoke(root.message.id, parent.modelData.identifier)
                }
            }
        }
        Rectangle {
            visible: root.url !== ""
            width: 82
            height: 30
            radius: 9
            color: linkMouse.containsMouse ? Theme.overlaySurfaceHover : Theme.popupSurface
            border.color: Theme.popupBorder
            Text {
                anchors.centerIn: parent
                text: "Open link"
                color: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
            }
            MouseArea {
                id: linkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(root.url)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            id: timeoutTrack
            visible: root.hasMessage && root.message.timeout !== 0
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.popupBorder
            Rectangle {
                property real progress: root.receiver.remaining
                width: parent.width * progress
                height: parent.height
                radius: parent.radius
                color: Theme.popupAccent
                Behavior on progress {
                    enabled: root.receiver.remaining < 1
                    NumberAnimation {
                        duration: 65
                        easing.type: Easing.Linear
                    }
                }
            }
        }
        Item {
            visible: !timeoutTrack.visible
            Layout.fillWidth: true
        }
        Rectangle {
            Layout.preferredWidth: 68
            Layout.preferredHeight: 29
            radius: 9
            color: closeMouse.containsMouse ? Theme.overlaySurfaceHover : Theme.popupSurface
            border.color: Theme.popupBorder
            Text {
                anchors.centerIn: parent
                text: root.receiver.queue.length ? "Next" : "Close"
                color: Theme.popupText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeCaption
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.receiver.closeCurrent()
            }
        }
    }
}
