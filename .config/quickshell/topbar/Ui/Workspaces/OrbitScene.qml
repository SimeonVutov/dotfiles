pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "OrbitalMotion.js" as Motion
import "OrbitFlight.js" as Flight

Item {
    id: root

    property var workspaces: []
    property var workspaceMonitor: null
    property int activeId: -1
    property bool motionEnabled: true
    property bool scrollEnabled: true
    signal workspaceRequested(int workspaceId)
    signal wheelRequested(int direction)

    property var pose: null
    property var flight: null
    property bool pendingReflow: false
    property var layoutRoutes: ({})
    property int layoutRevision: 0
    property int cachedBodiesRevision: -1
    property var cachedBodies: []
    property real layoutClock: 0
    property real layoutUntil: 0
    property bool layoutMoving: false
    property real targetWidth: 0
    property real heading: 0
    property real throttle: 0
    property real braking: 0
    property real clock: 0
    property int settledActiveId: -1
    property real lastActiveChangeAt: 0
    property real emptySince: 0
    property bool ready: false
    property var pendingBodies: ({})
    property var trailPoints: []
    property int trailHead: -1
    property real trailClock: 0
    property real nextTrailAt: 0
    property real wheelSteps: 0
    property real lastWheelAt: -1000
    property int retiringCount: 0
    readonly property int stride: 48
    readonly property int trailCapacity: 80
    readonly property real trailInterval: 1 / 90
    readonly property real reflowDuration: 0.38

    implicitWidth: targetWidth
    implicitHeight: Theme.barHeight - Theme.pillMarginV * 2
    width: implicitWidth
    height: implicitHeight
    clip: true

    ListModel { id: slots }

    Behavior on implicitWidth {
        NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
    }

    Timer {
        id: activeSettle
        interval: 110
        onTriggered: {
            root.settledActiveId = root.activeId;
            root.queueSync();
        }
    }

    Timer {
        id: bodySettle
        interval: 130
        onTriggered: root.queueSync()
    }

    Timer {
        id: wheelDelay
        interval: 90
        onTriggered: root.flushWheel()
    }

    function queueSync() {
        if (ready)
            Qt.callLater(root.synchronize);
    }

    function flushWheel() {
        if (Math.abs(wheelSteps) < 120)
            return;
        const now = Date.now();
        const remaining = 90 - (now - lastWheelAt);
        if (remaining > 0) {
            if (!wheelDelay.running) {
                wheelDelay.interval = Math.ceil(remaining);
                wheelDelay.start();
            }
            return;
        }
        wheelRequested(wheelSteps > 0 ? -1 : 1);
        wheelSteps = 0;
        lastWheelAt = now;
    }

    function slotFor(id) {
        for (let i = 0; i < slots.count; ++i) {
            if (slots.get(i).workspaceId === id)
                return i;
        }
        return -1;
    }

    function layoutPose(id, time) {
        const route = layoutRoutes[id];
        if (!route)
            return null;
        return time >= route.started + route.duration
            ? route.end : Motion.sample(route, Math.max(0, time - route.started));
    }

    function centerFor(id, finalPosition) {
        const route = layoutRoutes[id];
        const center = route ? (finalPosition ? route.end : layoutPose(id, clock)) : null;
        return center ? center.p.slice(0, 2) : null;
    }

    function positionBody(id, x) {
        const end = { p: [x, height / 2, 0], v: [0, 0, 0], a: [0, 0, 0] };
        const previous = layoutRoutes[id];
        if (previous && previous.end.p[0] === x && previous.end.p[1] === height / 2)
            return false;
        const start = previous ? layoutPose(id, clock) : end;
        const duration = previous ? reflowDuration : 0;
        layoutRoutes[id] = { axes: Motion.coefficients(start, end, reflowDuration),
            duration: duration, started: clock, end: end };
        layoutUntil = Math.max(layoutUntil, clock + duration);
        if (duration > 0)
            layoutMoving = true;
        return true;
    }

    function seedBody(id) {
        let neighbor = null;
        for (let i = 0; i < slots.count; ++i) {
            const body = slots.get(i);
            const route = layoutRoutes[body.workspaceId];
            if (body.workspaceId === id || !body.live || !route)
                continue;
            if (!neighbor || Math.abs(body.workspaceId - id) < Math.abs(neighbor.id - id))
                neighbor = { id: body.workspaceId, center: route.end.p[0] };
        }
        if (!neighbor)
            return false;
        positionBody(id, neighbor.center);
        return true;
    }

    function setPresent(index, present) {
        const body = slots.get(index);
        if (body.live === present)
            return false;
        slots.setProperty(index, "live", present);
        if (!present) {
            slots.setProperty(index, "retiredAt", clock);
            ++retiringCount;
        } else {
            retiringCount = Math.max(0, retiringCount - 1);
        }
        return true;
    }

    function protectedBody(id) {
        return flight && (id === flight.orbitId
            || (flight.mode !== "orbit" && id === flight.targetId));
    }

    function updateWidth() {
        let extent = 0;
        for (let i = 0; i < slots.count; ++i) {
            const body = slots.get(i);
            const route = layoutRoutes[body.workspaceId];
            if (route && (body.live || protectedBody(body.workspaceId)))
                extent = Math.max(extent, route.end.p[0] + 28);
        }
        targetWidth = extent;
    }

    function reflow() {
        let moved = false;
        if (flight && flight.mode !== "orbit") {
            let extent = targetWidth;
            for (let i = 0; i < slots.count; ++i) {
                const id = slots.get(i).workspaceId;
                if (slots.get(i).live && slots.get(i).enteringAt === clock) {
                    moved = positionBody(id, extent + 20) || moved;
                    extent += stride;
                }
            }
            if (moved)
                clearTrail();
            pendingReflow = true;
            ++layoutRevision;
            updateWidth();
            return;
        }
        pendingReflow = false;
        const kept = [];
        const retired = [];
        for (let i = 0; i < slots.count; ++i)
            (slots.get(i).live || protectedBody(slots.get(i).workspaceId) ? kept : retired)
                .push(slots.get(i).workspaceId);
        kept.sort((a, b) => a - b);
        for (let i = 0; i < kept.length; ++i)
            moved = positionBody(kept[i], 28 + i * stride) || moved;
        for (const id of retired) {
            if (!kept.length)
                continue;
            const nearest = kept.reduce((best, candidate) =>
                Math.abs(candidate - id) < Math.abs(best - id) ? candidate : best, kept[0]);
            moved = positionBody(id, layoutRoutes[nearest].end.p[0]) || moved;
        }
        if (moved)
            clearTrail();
        ++layoutRevision;
        updateWidth();
    }

    function pruneRetired() {
        if (pendingReflow)
            return;
        let changed = false;
        for (let i = slots.count - 1; i >= 0; --i) {
            const body = slots.get(i);
            const route = layoutRoutes[body.workspaceId];
            if (!body.live && !protectedBody(body.workspaceId) && route
                    && clock >= route.started + route.duration
                    && clock - body.retiredAt >= reflowDuration) {
                delete layoutRoutes[body.workspaceId];
                slots.remove(i);
                --retiringCount;
                changed = true;
            }
        }
        if (changed) {
            reflow();
        }
    }

    function synchronize() {
        if (!ready)
            return;
        const observed = workspaces.filter(workspace => workspace && workspace.id > 0)
            .map(workspace => ({ workspaceId: workspace.id, label: String(workspace.name) }))
            .filter((workspace, index, list) => list.findIndex(other => other.workspaceId === workspace.workspaceId) === index)
            .sort((a, b) => a.workspaceId - b.workspaceId);
        const now = Date.now();
        if (!observed.length && activeId < 1) {
            if (!slots.count)
                return;
            if (!emptySince)
                emptySince = now;
            if (now - emptySince < bodySettle.interval) {
                if (!bodySettle.running)
                    bodySettle.start();
                return;
            }
            resetForMonitor();
            return;
        }
        emptySince = 0;
        const observedIds = new Set(observed.map(workspace => workspace.workspaceId));
        for (const id of Object.keys(pendingBodies)) {
            if (!observedIds.has(Number(id)))
                delete pendingBodies[id];
        }
        let waiting = false;
        const desired = observed.filter(workspace => {
            const id = workspace.workspaceId;
            if (slotFor(id) >= 0 || slots.count === 0) {
                delete pendingBodies[id];
                return true;
            }
            if (pendingBodies[id] === undefined)
                pendingBodies[id] = now;
            if ((id === activeId && settledActiveId !== activeId)
                    || now - pendingBodies[id] < bodySettle.interval
                    || now - lastActiveChangeAt < bodySettle.interval) {
                waiting = true;
                return false;
            }
            delete pendingBodies[id];
            return true;
        });
        if (waiting && !bodySettle.running)
            bodySettle.start();
        const desiredIds = new Set(desired.map(workspace => workspace.workspaceId));
        let changed = false;
        for (let i = 0; i < desired.length; ++i) {
            const index = slotFor(desired[i].workspaceId);
            if (index < 0) {
                const entering = seedBody(desired[i].workspaceId);
                slots.append({ workspaceId: desired[i].workspaceId, label: desired[i].label,
                    live: true, retiredAt: -1,
                    enteringAt: entering ? clock : clock - reflowDuration });
                changed = true;
            } else {
                if (slots.get(index).label !== desired[i].label)
                    slots.setProperty(index, "label", desired[i].label);
                changed = setPresent(index, true) || changed;
            }
        }
        for (let i = 0; i < slots.count; ++i) {
            if (!desiredIds.has(slots.get(i).workspaceId))
                changed = setPresent(i, false) || changed;
        }
        if (changed) {
            reflow();
        }
        if (!desiredIds.has(activeId))
            return;
        if (!Motion.finitePose(pose)) {
            flight = Flight.create(activeId, centerFor(activeId, false));
            pose = flight.pose;
            heading = flight.heading;
        }
        if (flight)
            Flight.request(flight, activeId);
    }

    function flightBodies() {
        if (clock >= layoutUntil && cachedBodiesRevision === layoutRevision)
            return cachedBodies;
        const bodies = [];
        for (let i = 0; i < slots.count; ++i) {
            const body = slots.get(i);
            const route = layoutRoutes[body.workspaceId];
            if (route)
                bodies.push({ id: body.workspaceId, center: centerFor(body.workspaceId, false),
                    live: body.live, settled: clock >= route.started + route.duration });
        }
        if (clock >= layoutUntil) {
            cachedBodies = bodies;
            cachedBodiesRevision = layoutRevision;
        }
        return bodies;
    }

    function trailPoint(ageIndex) {
        return trailHead < 0 ? null : trailPoints[(trailHead - ageIndex + trailCapacity) % trailCapacity] || null;
    }

    function clearTrail() {
        trailPoints = [];
        trailHead = -1;
        trailClock = clock;
        nextTrailAt = clock;
    }

    function advance(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return;
        const dt = Math.min(seconds, 0.25);
        clock += seconds;
        if (layoutClock < layoutUntil)
            layoutClock = Math.min(clock, layoutUntil);
        if (layoutMoving && clock >= layoutUntil) {
            layoutMoving = false;
            clearTrail();
        }
        if (retiringCount > 0)
            pruneRetired();
        if (slots.count === 0) {
            pose = null;
            flight = null;
            clearTrail();
            return;
        }
        if (!Motion.finitePose(pose)) {
            synchronize();
            if (!Motion.finitePose(pose))
                return;
        }
        if (settledActiveId === activeId)
            Flight.request(flight, activeId);
        const bodies = flightBodies();
        if (flight.mode === "orbit" && !bodies.some(body => body.id === flight.orbitId)) {
            const fallback = bodies.find(body => body.id === activeId && body.live)
                || bodies.find(body => body.live);
            if (!fallback) {
                flight = null;
                pose = null;
                clearTrail();
                return;
            }
            flight = Flight.create(fallback.id, fallback.center);
            clearTrail();
        }
        const previousOrbitId = flight.orbitId;
        Flight.advance(flight, dt, bodies);
        pose = flight.pose;
        heading = flight.heading;
        throttle = flight.throttle;
        braking = flight.braking;
        if (previousOrbitId !== flight.orbitId || (pendingReflow && flight.mode === "orbit"))
            reflow();
        if (!Motion.finitePose(pose))
            return;
        if (!layoutMoving && clock >= nextTrailAt) {
            const next = (trailHead + 1) % trailCapacity;
            trailPoints[next] = { x: pose.p[0], y: pose.p[1], z: pose.p[2], heat: throttle, time: clock };
            trailHead = next;
            trailClock = clock;
            nextTrailAt = nextTrailAt < clock - trailInterval
                ? clock + trailInterval : nextTrailAt + trailInterval;
        }
    }

    function resetForMonitor() {
        activeSettle.stop();
        bodySettle.stop();
        wheelDelay.stop();
        slots.clear();
        pendingBodies = ({});
        layoutRoutes = ({});
        ++layoutRevision;
        cachedBodiesRevision = -1;
        cachedBodies = [];
        layoutClock = clock;
        layoutUntil = clock;
        layoutMoving = false;
        targetWidth = 0;
        flight = null;
        pose = null;
        clearTrail();
        retiringCount = 0;
        wheelSteps = 0;
        lastWheelAt = -1000;
        settledActiveId = activeId;
        lastActiveChangeAt = 0;
        emptySince = 0;
        queueSync();
    }

    Component.onCompleted: {
        ready = true;
        settledActiveId = activeId;
        synchronize();
    }
    onWorkspacesChanged: queueSync()
    onActiveIdChanged: {
        lastActiveChangeAt = Date.now();
        if (bodySettle.running)
            bodySettle.restart();
        if (slotFor(activeId) >= 0) {
            activeSettle.stop();
            settledActiveId = activeId;
        } else {
            activeSettle.restart();
        }
        queueSync();
    }
    onWorkspaceMonitorChanged: if (ready) resetForMonitor()
    onScrollEnabledChanged: {
        if (!scrollEnabled) {
            wheelDelay.stop();
            wheelSteps = 0;
        }
    }

    FrameAnimation {
        running: root.motionEnabled && root.visible && root.Window.window !== null
            && root.Window.window.visible && root.flight !== null
        onTriggered: root.advance(frameTime)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: Theme.pillBackground
        opacity: Theme.pillOpacity
        z: -2
    }

    Repeater {
        model: root.trailCapacity - 1

        Rectangle {
            required property int index
            readonly property var head: root.trailPoint(index)
            readonly property var tail: root.trailPoint(index + 1)
            readonly property bool connected: head && tail && head.time - tail.time < 0.09
                && head.z * tail.z >= 0
                && Math.hypot(tail.x - head.x, tail.y - head.y) < 36
            readonly property real age: head ? root.trailClock - head.time : 2
            x: head ? head.x : 0
            y: head ? head.y - height / 2 : 0
            width: connected ? Math.hypot(tail.x - head.x, tail.y - head.y) + 0.25 : 0
            height: 1.2
            radius: 0.6
            transformOrigin: Item.Left
            rotation: head && tail ? Math.atan2(tail.y - head.y, tail.x - head.x) * 180 / Math.PI : 0
            color: head && head.heat > 0.25 ? "#E8C59B" : "#FFFFFF"
            opacity: Math.max(0, 1 - age / 1.05) * 0.58
            visible: connected && opacity > 0
            z: head && head.z > 0 ? 2 : 0
        }
    }

    Repeater {
        id: planets
        model: slots

        Planet {
            required property bool live
            required property real enteringAt
            readonly property var position: root.layoutPose(workspaceId, root.layoutClock, root.layoutRevision)
            x: position ? position.p[0] - width / 2 : 0
            interactive: live
            selected: workspaceId === root.activeId
            z: live && root.layoutClock - enteringAt >= root.reflowDuration ? 1 : 0
            onActivated: root.workspaceRequested(workspaceId)
        }
    }

    Repeater {
        model: 8

        Rectangle {
            required property int index
            readonly property var point: root.trailPoint(index * 3)
            readonly property real age: point ? root.trailClock - point.time : 2
            x: point ? point.x + Math.sin(index * 12.7) * age * 12 : 0
            y: point ? point.y + Math.cos(index * 8.3) * age * 10 : 0
            width: index % 3 === 0 ? 1.5 : 1
            height: width
            radius: width / 2
            color: "#FFE4BD"
            opacity: point ? point.heat * Math.max(0, 1 - age / 0.5) * 0.8 : 0
            visible: opacity > 0.01
            z: point && point.z > 0 ? 2 : 0
        }
    }

    OrbitalShip {
        visible: root.pose !== null
        x: root.pose ? root.pose.p[0] - width / 2 : 0
        y: root.pose ? root.pose.p[1] - height / 2 : 0
        z: root.pose && root.pose.p[2] > 0 ? 3 : 0
        rotation: root.heading * 180 / Math.PI
        scale: root.pose ? 1.05 + Math.max(-1, Math.min(1, root.pose.p[2] / Motion.radiusZ)) * 0.04 : 1.05
        throttle: root.throttle
        braking: root.braking
        clock: root.clock
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        enabled: root.scrollEnabled
        onWheel: wheel => {
            const delta = wheel.angleDelta.y || wheel.pixelDelta.y * 2;
            if (!delta)
                return;
            if (root.wheelSteps * delta < 0)
                root.wheelSteps = 0;
            root.wheelSteps = Math.max(-120, Math.min(120, root.wheelSteps + delta));
            root.flushWheel();
            wheel.accepted = true;
        }
    }
}
