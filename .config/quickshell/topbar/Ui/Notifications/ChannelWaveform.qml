import QtQuick
import qs.Common

// Reception activity only. The current message sustains the carrier, while
// ChannelBuffer represents waiting messages independently of this animation.
Item {
    id: root
    required property var receiver
    property real clock: 0
    property int serial: 0
    property var transmissions: []
    property real readingLevel: receiver.current !== null || receiver.phase === "handoff" ? 1 : 0
    readonly property real transmissionDuration: 1.45
    // Render at twice the logical size, then let Qt scale the single texture
    // down. This avoids gaps in thin geometry on the live scene graph renderer.
    Canvas {
        id: surface
        width: root.width * 2
        height: root.height * 2
        scale: 0.5
        transformOrigin: Item.TopLeft
        smooth: true
        antialiasing: true
        renderTarget: Canvas.Image
        onPaint: root.paintTrace(getContext("2d"))
    }

    Behavior on readingLevel {
        NumberAnimation {
            duration: 350
            easing.type: Easing.InOutSine
        }
    }

    function receive(message) {
        let hash = ++serial * 7919;
        const text = String(message.sender || "") + String(message.title || "");
        for (let i = 0; i < text.length; i++)
            hash = ((hash * 31) ^ text.charCodeAt(i)) >>> 0;
        const event = {
            start: clock,
            seed: (hash % 10007) / 10007,
            strength: 1
        };
        // Closely spaced arrivals reinforce the same reception burst. Older
        // transmissions finish naturally; a new arrival never evicts one.
        const last = transmissions[transmissions.length - 1];
        if (last && (clock - last.start < 0.09 || transmissions.length >= 16)) {
            last.strength = Math.min(2.5, last.strength + 0.25);
        } else {
            transmissions = transmissions.concat([event]);
        }
    }

    Connections {
        target: root.receiver
        function onArrival(message) {
            root.receive(message);
        }
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.clock += Math.min(frameTime, 0.05);
            if (root.transmissions.some(event => root.clock - event.start >= root.transmissionDuration))
                root.transmissions = root.transmissions.filter(event => root.clock - event.start < root.transmissionDuration);
            surface.requestPaint();
        }
    }
    onWidthChanged: surface.requestPaint()
    onHeightChanged: surface.requestPaint()

    function smoothstep(value) {
        const t = Math.max(0, Math.min(1, value));
        return t * t * (3 - 2 * t);
    }

    function paintTrace(ctx) {
        ctx.reset();
        if (width < 1 || height < 1)
            return;
        ctx.scale(2, 2);
        const mid = height / 2;
        const limit = mid - 3;
        const activityScale = 1 / Math.sqrt(Math.max(1, transmissions.length));
        ctx.beginPath();
        for (let x = 0; x <= width; x += 0.25) {
            const u = x / width;
            const edge = smoothstep(u / 0.08) * smoothstep((1 - u) / 0.08);
            let wave = 0.75 * Math.sin(u * 8 + clock * 1.3) + 0.12 * Math.sin(u * 15 - clock * 0.8);
            // A quiet continuous modulation connects the bar to the open message.
            wave += readingLevel * (2.1 * Math.sin(u * 17 - clock * 2.7) + 0.25 * Math.sin(u * 26 + clock * 1.8));
            for (const event of transmissions) {
                // Excitation spreads from the right through the carrier; no
                // discrete packet slides across or parks at a queue position.
                const age = clock - event.start - (1 - u) * 0.18;
                if (age <= 0)
                    continue;
                const attack = smoothstep(age / 0.14);
                const release = 1 - smoothstep((age - 0.65) / 0.6);
                const rhythm = 0.58 + 0.27 * Math.sin(age * (10 + event.seed * 7) + event.seed * 6) + 0.15 * Math.sin(age * 25 + event.seed * 11);
                const phase = u * (20 + event.seed * 12) - age * (9 + event.seed * 5);
                wave += activityScale * event.strength * 8 * attack * release * rhythm * (Math.sin(phase) + 0.18 * Math.sin(phase * 1.6 + event.seed * 8));
            }
            const y = mid + limit * Math.tanh(wave / limit) * edge;
            if (x === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = Theme.popupAccent.toString();
        ctx.globalAlpha = 0.85;
        ctx.lineWidth = 1.65;
        ctx.stroke();
    }
}
