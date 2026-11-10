import QtQuick

Canvas {
    id: root

    property real progress: 0
    property bool active: false

    visible: active
    onProgressChanged: requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.reset();

        const inset = 4;
        const w = Math.max(0, width - inset * 2);
        const h = Math.max(0, height - inset * 2);
        const radius = h / 2;
        const perimeter = 2 * Math.max(0, w - h) + Math.PI * h;
        if (perimeter <= 0)
            return;

        context.beginPath();
        context.roundedRect(inset, inset, w, h, radius, radius);
        context.setLineDash([perimeter * .23, perimeter * .77]);
        context.lineDashOffset = -progress * perimeter * 2;
        context.lineCap = "round";

        context.strokeStyle = "#ff5364";
        context.lineWidth = 2;
        context.stroke();
    }
}
