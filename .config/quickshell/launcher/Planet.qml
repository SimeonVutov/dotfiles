import QtQuick

// Projected spherical mesh with depth-sensitive lines and a shaded surface.
// Cached between geometry changes: moving the planet does not repaint it.
Canvas {
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.translate(width / 2, height / 2);
        const r = Math.min(width, height) / 2 - 2;
        c.beginPath();
        c.arc(0, 0, r, 0, Math.PI * 2);
        c.fillStyle = "#0a0a0a";
        c.fill();
        {
            function project(lat, lon) {
                const x = Math.cos(lat) * Math.cos(lon);
                const y = Math.sin(lat), z = Math.cos(lat) * Math.sin(lon);
                return {
                    x: x * r,
                    y: (y * Math.cos(.38) - z * Math.sin(.38)) * r,
                    z: y * Math.sin(.38) + z * Math.cos(.38)
                };
            }
            function segment(a, b, front) {
                if ((a.z + b.z >= 0) !== front)
                    return;
                c.moveTo(a.x, a.y);
                c.lineTo(b.x, b.y);
            }
            for (const front of [false, true]) {
                c.beginPath();
                for (let j = -5; j <= 5; j++)
                    for (let i = 0; i < 96; i++)
                        segment(project(j * Math.PI / 12, i * Math.PI / 48), project(j * Math.PI / 12, (i + 1) * Math.PI / 48), front);
                for (let j = 0; j < 20; j++)
                    for (let i = 0; i < 48; i++)
                        segment(project(-Math.PI / 2 + i * Math.PI / 48, j * Math.PI / 10), project(-Math.PI / 2 + (i + 1) * Math.PI / 48, j * Math.PI / 10), front);
                c.strokeStyle = front ? "#bcbcbc" : "#303030";
                c.lineWidth = front ? .8 : .5;
                c.stroke();
            }
        }
        c.beginPath();
        c.arc(0, 0, r, 0, Math.PI * 2);
        c.strokeStyle = "#eeeeee";
        c.lineWidth = .8;
        c.stroke();
    }
}
