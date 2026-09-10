import QtQuick

// The two orbital paths the satellites sit on. Painted once; the satellites
// move over it, this never repaints.
Canvas {
    property var radii: []

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.translate(width / 2, height / 2);
        c.strokeStyle = Theme.orbit;
        c.lineWidth = 1;
        for (const r of radii) {
            c.beginPath();
            c.ellipse(-r[0], -r[1], r[0] * 2, r[1] * 2);
            c.stroke();
        }
    }
}
