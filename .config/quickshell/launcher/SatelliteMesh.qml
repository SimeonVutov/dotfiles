import QtQuick
import Quickshell

Item {
    id: root
    property string icon: ""
    property string fallback: ""
    property real yaw: -.25
    // Geometry is painted once per orientation/size, not on every drifting frame.
    function project(p) {
        const x = p[0] * Math.cos(yaw) + p[2] * Math.sin(yaw);
        const z = -p[0] * Math.sin(yaw) + p[2] * Math.cos(yaw);
        const y = p[1] * Math.cos(-.32) - z * Math.sin(-.32);
        const depth = p[1] * Math.sin(-.32) + z * Math.cos(-.32);
        return {
            x: width / 2 + x * width / 170,
            y: height / 2 + y * width / 170,
            z: depth
        };
    }
    readonly property var iconCenter: project([0, 0, 17])
    onYawChanged: mesh.requestPaint()

    Canvas {
        id: mesh
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const faces = [];
            function face(points, shade, edge) {
                const projected = points.map(p => root.project(p));
                faces.push({
                    points: projected,
                    shade: shade,
                    edge: edge || "#777777",
                    depth: projected.reduce((s, p) => s + p.z, 0) / points.length
                });
            }
            function box(x, y, z, w, h, d, front) {
                const a = [x, y, z], b = [x + w, y, z], e = [x, y + h, z], f = [x + w, y + h, z];
                const A = [x, y, z + d], B = [x + w, y, z + d], E = [x, y + h, z + d], F = [x + w, y + h, z + d];
                face([a, b, f, e], "#333333");
                face([a, A, B, b], "#d5d5d5");
                face([e, f, F, E], "#3a3a3a");
                face([a, e, E, A], "#767676");
                face([b, B, F, f], "#999999");
                face([A, E, F, B], front || "#a9a9a9");
            }
            // Bus, mounting arms, reinforced solar arrays, and individual cells.
            box(-22, -2, -3, 44, 4, 4, "#b6b6b6");
            for (const side of [-1, 1]) {
                const x = side < 0 ? -76 : 26;
                box(x, -24, -2, 50, 48, 2, "#777777");
                for (let col = 0; col < 5; col++)
                    for (let row = 0; row < 6; row++) {
                        const px = x + 2 + col * 9.4, py = -22 + row * 7.3;
                        face([[px, py, 1], [px + 8, py, 1], [px + 8, py + 6, 1], [px, py + 6, 1]], (row + col) % 3 === 0 ? "#343434" : "#202020", "#555555");
                        face([[px + 3.8, py, 1.2], [px + 4.2, py, 1.2], [px + 4.2, py + 6, 1.2], [px + 3.8, py + 6, 1.2]], "#888888", "#888888");
                    }
            }
            box(-17, -19, -13, 34, 38, 28, "#8f8f8f");
            // Front-face bezel, corner fasteners, and layered thermal shielding.
            box(-13, -15, 15, 26, 30, 1, "#202020");
            for (const x of [-15, 14])
                for (const y of [-17, 16])
                    box(x, y, 15, 1.5, 1.5, 1, "#eeeeee");
            for (let i = 0; i < 5; i++)
                box(-12 + i * 5, -20, -8, 2, 1, 17, "#bcbcbc");
            box(-2, -35, -2, 4, 16, 4, "#cccccc");
            // Faceted parabolic antenna bowl: distinct concave surface and rim.
            for (let i = 0; i < 24; i++) {
                const a = i * Math.PI / 12, b = (i + 1) * Math.PI / 12;
                face([[0, -34, 2], [Math.cos(a) * 13, -34 + Math.sin(a) * 7, 9], [Math.cos(b) * 13, -34 + Math.sin(b) * 7, 9]], i % 2 ? "#c1c1c1" : "#9d9d9d", "#8c8c8c");
            }
            box(-.7, -35, 4, 1.4, 2, 18, "#dddddd");
            faces.sort((a, b) => a.depth - b.depth);
            for (const f of faces) {
                c.beginPath();
                c.moveTo(f.points[0].x, f.points[0].y);
                for (let i = 1; i < f.points.length; i++)
                    c.lineTo(f.points[i].x, f.points[i].y);
                c.closePath();
                c.fillStyle = f.shade;
                c.fill();
                c.strokeStyle = f.edge;
                c.lineWidth = .35;
                c.stroke();
            }
        }
    }
    Image {
        id: badge
        x: root.iconCenter.x - width / 2
        y: root.iconCenter.y - height / 2
        width: root.width * .135
        height: width
        source: root.icon ? Quickshell.iconPath(root.icon, true) : ""
        sourceSize.width: 48
        sourceSize.height: 48
        asynchronous: true
        transform: Rotation {
            origin.x: badge.width / 2
            origin.y: badge.height / 2
            axis.y: 1
            axis.x: 0
            angle: root.yaw * 180 / Math.PI
        }
        Text {
            anchors.centerIn: parent
            visible: badge.status !== Image.Ready
            text: root.fallback
            font.pixelSize: 18
            color: Theme.text
        }
    }
}
