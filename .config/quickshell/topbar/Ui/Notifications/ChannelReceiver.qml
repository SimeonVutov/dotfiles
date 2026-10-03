import QtQuick
import qs.Services

// One visible message. A brief reception phase precedes FIFO delivery.
Item {
    id: root
    property string phase: "listening"
    property real clock: 0
    signal arrival(var message)
    property real unfold: 0
    property real contentOpacity: 1
    property var packets: []
    property var queue: []
    property var current: null
    property int serial: 0
    property int characters: 0
    property real remaining: 1
    property bool hovered: false
    readonly property int pendingCount: packets.length + queue.length
    readonly property real transitDuration: 0.65
    readonly property string bodyText: current ? plainBody(current.body || "") : ""
    readonly property string fullText: current ? (current.title || "") + (current.title && bodyText ? "\n" : "") + bodyText : ""
    readonly property bool typing: current !== null && characters < fullText.length
    readonly property string typedTitle: current ? (current.title || "").slice(0, characters) : ""
    readonly property string typedBody: current ? bodyText.slice(0, Math.max(0, characters - (current.title || "").length - (current.title && bodyText ? 1 : 0))) : ""

    function plainBody(markup) {
        return markup.replace(/<br\s*\/?\s*>/gi, "\n").replace(/<\/?[a-z][^>]*>/gi, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&#39;|&apos;/g, "'");
    }

    function enqueue(message, isArrival = true) {
        if (isArrival)
            arrival(message);
        if (current?.id === message.id) {
            current = message;
            characters = fullText.length;
            if (isArrival)
                remaining = 1;
            return;
        }
        const queued = queue.findIndex(item => item.id === message.id);
        if (queued >= 0) {
            const copy = queue.slice();
            copy[queued] = message;
            queue = copy;
            return;
        }
        const travelling = packets.findIndex(packet => packet.message.id === message.id);
        if (travelling >= 0) {
            const copy = packets.slice();
            copy[travelling].message = message;
            packets = copy;
            return;
        }
        serial++;
        packets = packets.concat([
            {
                id: serial,
                start: clock,
                message: message
            }
        ]);
        if (pendingCount > 40) {
            const oldest = queue.length ? queue[0] : packets[0]?.message;
            if (oldest)
                Notifications.dismiss(oldest.id, true);
        }
    }

    function forget(id) {
        packets = packets.filter(packet => packet.message.id !== id);
        queue = queue.filter(item => item.id !== id);
        if (current?.id !== id || phase === "handoff" || phase === "closing")
            return;
        typingTimer.stop();
        // Keep the outgoing content in place until handoff has faded it out.
        if (queue.length) {
            phase = "handoff";
            handoff.start();
        } else {
            phase = "closing";
            closing.start();
        }
    }

    function selectNext() {
        current = queue.length ? queue[0] : null;
        queue = queue.slice(1);
        characters = 0;
        remaining = 1;
    }

    function drain() {
        if ((phase !== "listening" && phase !== "empty") || !queue.length)
            return;
        const alreadyOpen = phase === "empty";
        selectNext();
        contentOpacity = 1;
        if (alreadyOpen) {
            phase = "reading";
            typingTimer.start();
        } else {
            phase = "opening";
            opening.start();
        }
    }

    function openConsole() {
        if (phase === "reading" || phase === "empty" || phase === "handoff")
            return;
        opening.stop();
        closing.stop();
        if (!current && queue.length)
            selectNext();
        unfold = 1;
        contentOpacity = 1;
        phase = current ? "reading" : "empty";
        if (typing)
            typingTimer.start();
    }

    function closeCurrent(expired = false) {
        if (phase === "listening" || phase === "closing" || phase === "handoff")
            return;
        opening.stop();
        typingTimer.stop();
        if (current) {
            const id = current.id;
            Notifications.dismiss(id, expired);
            if (current?.id === id && phase !== "handoff" && phase !== "closing")
                forget(id);
        } else {
            phase = "closing";
            closing.start();
        }
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            root.clock += 0.05;
            const received = root.packets.filter(packet => root.clock - packet.start >= root.transitDuration);
            if (received.length) {
                root.packets = root.packets.filter(packet => root.clock - packet.start < root.transitDuration);
                root.queue = root.queue.concat(received.map(packet => packet.message));
                root.drain();
            }
            if (root.phase !== "reading" || root.typing || root.hovered || !root.current)
                return;
            const timeout = root.current.timeout;
            if (timeout === 0)
                return;
            const duration = timeout > 0 ? Math.max(6000, timeout * 1000) : 8000;
            root.remaining = Math.max(0, root.remaining - 50 / duration);
            if (root.remaining === 0)
                root.closeCurrent(true);
        }
    }

    Timer {
        id: typingTimer
        interval: 20
        repeat: true
        onTriggered: {
            const step = Math.max(1, Math.ceil(root.fullText.length / 100));
            root.characters = Math.min(root.fullText.length, root.characters + step);
            if (!root.typing)
                stop();
        }
    }

    SequentialAnimation {
        id: opening
        NumberAnimation {
            target: root
            property: "unfold"
            to: 1
            duration: 260
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                root.phase = "reading";
                typingTimer.start();
            }
        }
    }
    SequentialAnimation {
        id: handoff
        NumberAnimation {
            target: root
            property: "contentOpacity"
            to: 0
            duration: 110
        }
        ScriptAction {
            script: root.selectNext()
        }
        NumberAnimation {
            target: root
            property: "contentOpacity"
            to: 1
            duration: 150
        }
        ScriptAction {
            script: {
                root.phase = root.current ? "reading" : "closing";
                if (root.typing)
                    typingTimer.start();
                if (!root.current)
                    closing.start();
            }
        }
    }
    SequentialAnimation {
        id: closing
        NumberAnimation {
            target: root
            property: "unfold"
            to: 0
            duration: 220
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: {
                root.hovered = false;
                root.phase = "listening";
                root.current = null;
                root.drain();
            }
        }
    }
}
