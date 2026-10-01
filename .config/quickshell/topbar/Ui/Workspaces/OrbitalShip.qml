import QtQuick

Item {
    id: root

    property real throttle: 0
    property real braking: 0
    property real clock: 0

    width: 11
    height: 7

    Rectangle {
        x: 8
        y: 0
        width: 5 * root.braking
        height: 1.2
        radius: 0.75
        color: "#FFE2B5"
        opacity: root.braking
    }

    Rectangle {
        x: 8
        y: 5.8
        width: 5 * root.braking
        height: 1.2
        radius: 0.75
        color: "#FFE2B5"
        opacity: root.braking
    }

    Canvas {
        x: -12
        y: -1.5
        width: 17
        height: 10
        opacity: root.throttle
        scale: 0.8 + 0.2 * root.throttle + 0.08 * Math.sin(root.clock * 85)
        visible: opacity > 0.01
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const glow = ctx.createRadialGradient(13, 5, 0, 10, 5, 9);
            glow.addColorStop(0, "#FFF4D0");
            glow.addColorStop(0.3, "#DDF2AC57");
            glow.addColorStop(1, "#00E87531");
            ctx.fillStyle = glow;
            ctx.fillRect(0, 0, 17, 10);
            ctx.fillStyle = "#FFE5AA";
            ctx.beginPath();
            ctx.moveTo(15, 3.5);
            ctx.lineTo(3, 5);
            ctx.lineTo(15, 6.5);
            ctx.fill();
            ctx.fillStyle = "#FFFFFF";
            ctx.fillRect(12, 4.3, 4, 1.4);
        }
    }

    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = "#A8A8A8";
            ctx.beginPath();
            ctx.moveTo(6, 3.5);
            ctx.lineTo(1, 0);
            ctx.lineTo(2, 3.5);
            ctx.lineTo(1, 7);
            ctx.closePath();
            ctx.fill();
            const hull = ctx.createLinearGradient(0, 1, 0, 6);
            hull.addColorStop(0, "#FFFFFF");
            hull.addColorStop(1, "#888888");
            ctx.fillStyle = hull;
            ctx.beginPath();
            ctx.moveTo(1.5, 2.1);
            ctx.quadraticCurveTo(8, 1, 11, 3.5);
            ctx.quadraticCurveTo(8, 6, 1.5, 4.9);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#303030";
            ctx.beginPath();
            ctx.arc(7, 3.5, 1, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}
