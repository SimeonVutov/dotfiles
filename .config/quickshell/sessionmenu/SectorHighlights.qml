pragma ComponentBehavior: Bound

import QtQuick
import qs.Common as Shared

// The filled arc behind the highlighted action. Each sector is painted once;
// only its opacity animates on hover.
Repeater {
    id: root

    required property MenuGeometry geometry
    required property int highlighted

    readonly property color fill: "#141414"

    model: 6

    Canvas {
        required property int index

        anchors.fill: parent
        opacity: root.highlighted === index ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Shared.Theme.overlayMotion
            }
        }
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const start = (index * root.geometry.sectorAngleStep + root.geometry.sectorAngleOffset - root.geometry.sectorHalfSpanDegrees) * Math.PI / 180;
            const end = (index * root.geometry.sectorAngleStep + root.geometry.sectorAngleOffset + root.geometry.sectorHalfSpanDegrees) * Math.PI / 180;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, root.geometry.sectorOuterRadius, start, end);
            ctx.arc(width / 2, height / 2, root.geometry.sectorInnerRadius, end, start, true);
            ctx.closePath();
            ctx.fillStyle = root.fill;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, root.geometry.sectorStrokeRadius, start, end);
            ctx.strokeStyle = Shared.Theme.overlayMuted;
            ctx.lineWidth = root.geometry.sectorStrokeWidth;
            ctx.stroke();
        }
    }
}
