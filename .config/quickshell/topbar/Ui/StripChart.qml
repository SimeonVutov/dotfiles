import QtQuick
import qs.Common

Canvas {
    id: root
    property var samples: []
    property color accent: Theme.graphCpu
    property real maximum: 100
    property bool active: false

    onSamplesChanged: if (active)
        requestPaint()
    onActiveChanged: if (active)
        requestPaint()
    onWidthChanged: if (active)
        requestPaint()
    onHeightChanged: if (active)
        requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const step = (width - 6) / (Config.hardware.historySamples - 1);
        function x(i) {
            return 3 + i * step;
        }
        function y(i) {
            return height - 3 - Math.max(0, Math.min(1, samples[i] / maximum)) * (height - 6);
        }
        ctx.strokeStyle = Qt.alpha(accent, 0.10);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(0, height - 1);
        ctx.lineTo(width, height - 1);
        ctx.stroke();

        // A fixed-width window grows from the left, then drops its oldest sample.
        let start = 0;
        while (start < samples.length) {
            while (start < samples.length && !isFinite(samples[start]))
                start++;
            let end = start;
            while (end < samples.length && isFinite(samples[end]))
                end++;
            if (start === end)
                break;
            ctx.beginPath();
            ctx.moveTo(x(start), height);
            for (let i = start; i < end; i++)
                ctx.lineTo(x(i), y(i));
            ctx.lineTo(x(end - 1), height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(accent, 0.22));
            fill.addColorStop(1, Qt.alpha(accent, 0.02));
            ctx.fillStyle = fill;
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(x(start), y(start));
            for (let i = start + 1; i < end; i++)
                ctx.lineTo(x(i), y(i));
            ctx.strokeStyle = Qt.alpha(accent, 0.9);
            ctx.lineWidth = 1.5;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(x(end - 1), y(end - 1), 2.5, 0, Math.PI * 2);
            ctx.fillStyle = accent;
            ctx.fill();
            start = end;
        }
    }
}
