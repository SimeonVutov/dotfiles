import QtQuick

Canvas {
    id: root

    property real tilt: .38

    readonly property int latitudeCount: 11
    readonly property int meridianCount: 20
    readonly property int segmentCount: 96

    readonly property real edgeInset: 2
    readonly property real nearLineWidth: .8
    readonly property real farLineWidth: .5

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onTiltChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.translate(width / 2, height / 2);

        const radius = Math.min(width, height) / 2 - root.edgeInset;
        const segment = 2 * Math.PI / root.segmentCount;

        function project(lat, lon) {
            const x = Math.cos(lat) * Math.cos(lon);
            const y = Math.sin(lat);
            const z = Math.cos(lat) * Math.sin(lon);
            return {
                x: x * radius,
                y: (y * Math.cos(root.tilt) - z * Math.sin(root.tilt)) * radius,
                z: y * Math.sin(root.tilt) + z * Math.cos(root.tilt)
            };
        }

        // Near and far halves are stroked separately, so each segment is drawn
        // only on the pass matching the side it faces.
        function trace(a, b, near) {
            if ((a.z + b.z >= 0) !== near)
                return;
            ctx.moveTo(a.x, a.y);
            ctx.lineTo(b.x, b.y);
        }

        function ring(index, near) {
            const lat = (index - (root.latitudeCount - 1) / 2) * Math.PI / (root.latitudeCount + 1);
            for (let i = 0; i < root.segmentCount; i++)
                trace(project(lat, i * segment), project(lat, (i + 1) * segment), near);
        }

        function meridian(index, near) {
            const lon = index * 2 * Math.PI / root.meridianCount;
            for (let i = 0; i < root.segmentCount / 2; i++)
                trace(project(-Math.PI / 2 + i * segment, lon), project(-Math.PI / 2 + (i + 1) * segment, lon), near);
        }

        for (const near of [false, true]) {
            ctx.beginPath();
            for (let i = 0; i < root.latitudeCount; i++)
                ring(i, near);
            for (let i = 0; i < root.meridianCount; i++)
                meridian(i, near);
            ctx.strokeStyle = near ? Theme.muted : Theme.border;
            ctx.lineWidth = near ? root.nearLineWidth : root.farLineWidth;
            ctx.stroke();
        }

        ctx.beginPath();
        ctx.arc(0, 0, radius, 0, Math.PI * 2);
        ctx.strokeStyle = Theme.text;
        ctx.lineWidth = 1;
        ctx.stroke();
    }
}
