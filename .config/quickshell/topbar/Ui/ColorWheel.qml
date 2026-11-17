import QtQuick

Item {
    id: root

    property real hue: 0
    property real saturation: 0
    property real brightness: 1
    signal picked(real hue, real saturation)

    implicitWidth: 220
    implicitHeight: 220
    onBrightnessChanged: wheel.requestPaint()

    Canvas {
        id: wheel
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            const centreX = width / 2;
            const centreY = height / 2;
            const radius = Math.min(width, height) / 2 - 7;
            context.reset();

            for (let angle = 0; angle < 360; angle += 2) {
                const gradient = context.createRadialGradient(centreX, centreY, 0, centreX, centreY, radius);
                gradient.addColorStop(0, Qt.hsva(0, 0, root.brightness, 1).toString());
                gradient.addColorStop(1, Qt.hsva(angle / 360, 1, root.brightness, 1).toString());
                context.fillStyle = gradient;
                context.beginPath();
                context.moveTo(centreX, centreY);
                context.arc(centreX, centreY, radius, (angle - .2) * Math.PI / 180, (angle + 2.2) * Math.PI / 180);
                context.closePath();
                context.fill();
            }
        }
    }

    Rectangle {
        width: 12
        height: 12
        radius: 6
        color: "transparent"
        border.color: "#111111"
        border.width: 2
        x: root.width / 2 + Math.cos(root.hue * 2 * Math.PI) * root.saturation * (Math.min(root.width, root.height) / 2 - 7) - width / 2
        y: root.height / 2 + Math.sin(root.hue * 2 * Math.PI) * root.saturation * (Math.min(root.width, root.height) / 2 - 7) - height / 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: width / 2
            color: "transparent"
            border.color: "#ffffff"
        }
    }

    MouseArea {
        anchors.fill: parent

        function pick(x, y) {
            const dx = x - width / 2;
            const dy = y - height / 2;
            const radius = Math.min(width, height) / 2 - 7;
            const hue = (Math.atan2(dy, dx) / (2 * Math.PI) + 1) % 1;
            root.picked(hue, Math.min(1, Math.sqrt(dx * dx + dy * dy) / radius));
        }

        onPressed: mouse => pick(mouse.x, mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                pick(mouse.x, mouse.y);
        }
    }
}
