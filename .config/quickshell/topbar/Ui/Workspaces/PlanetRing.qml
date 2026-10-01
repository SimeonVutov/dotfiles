import QtQuick

Canvas {
    property bool foreground: false
    property real tilt: -0.35

    width: 40
    height: 30
    antialiasing: true
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.translate(width / 2, height / 2);
        ctx.rotate(tilt);
        ctx.scale(1, 0.32);
        ctx.beginPath();
        ctx.arc(0, 0, 16, foreground ? 0 : Math.PI, foreground ? Math.PI : Math.PI * 2);
        ctx.strokeStyle = "#999999";
        ctx.lineWidth = 2.2;
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(0, 0, 17.7, foreground ? 0 : Math.PI, foreground ? Math.PI : Math.PI * 2);
        ctx.strokeStyle = "#CCCCCC";
        ctx.lineWidth = 0.7;
        ctx.stroke();
    }
    onVisibleChanged: if (visible) requestPaint()
    onTiltChanged: requestPaint()
}
