import QtQuick

// One filter choice: an icon button that grows slightly while active or hovered.
Item {
    id: root

    required property MatugenColors theme
    // Which icon to draw: "all" (four squares) or "video" (a play triangle).
    required property string icon
    property bool active: false

    signal clicked

    readonly property int transitionDuration: 180
    readonly property color iconColor: active ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)

    width: 44
    height: 38

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: root.active ? root.theme.surface1 : "transparent"

        border.color: root.active ? root.theme.text : Qt.rgba(root.theme.surface2.r, root.theme.surface2.g, root.theme.surface2.b, 0.5)
        border.width: root.active ? 2 : 1

        scale: root.active ? 1.08 : (area.containsMouse ? 1.05 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: Easing.OutQuad
            }
        }

        Canvas {
            visible: root.icon === "all"
            width: 14
            height: 14
            anchors.centerIn: parent

            property color paintColor: root.iconColor
            onPaintColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = paintColor;
                ctx.fillRect(0, 0, 6, 6);
                ctx.fillRect(8, 0, 6, 6);
                ctx.fillRect(0, 8, 6, 6);
                ctx.fillRect(8, 8, 6, 6);
            }
        }

        Canvas {
            visible: root.icon !== "all"
            width: 14
            height: 16
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 2

            property color paintColor: root.iconColor
            onPaintColorChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = paintColor;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.lineTo(14, 8);
                ctx.lineTo(0, 16);
                ctx.closePath();
                ctx.fill();
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
