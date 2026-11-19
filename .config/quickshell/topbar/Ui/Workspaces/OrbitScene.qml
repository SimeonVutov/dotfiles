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
    property bool shipActive: true
    signal workspaceRequested(int workspaceId)
    signal wheelRequested(int direction)

    property var pose: null
    property var flight: null
    property int flightRevision: 0
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
    property bool externalDeparture: false
    property real throttle: 0
    property real braking: 0
    property real clock: 0
    property int settledActiveId: -1
    property real lastActiveChangeAt: 0
    property real emptySince: 0
    property bool ready: false
    property var pendingBodies: ({})
    property int retiringCount: 0
    readonly property int stride: 48
    readonly property real reflowDuration: 0.38

    implicitWidth: targetWidth
    implicitHeight: Theme.barHeight - Theme.pillMarginV * 2
    width: implicitWidth
    height: implicitHeight
    clip: true

    ListModel { id: slots }

    TrailBuffer { id: trailBuffer }

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

    function queueSync() {
        if (ready)
            Qt.callLater(root.synchronize);
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

    function setPresent(index, present) {
        const body = slots.get(index);
        if (body.live === present)
            return false;
        slots.setProperty(index, "live", present);
        if (!present) {
            if (!layoutRoutes[body.workspaceId] || (!body.revealed && !protectedBody(body.workspaceId)))
                slots.setProperty(index, "closed", true);
            ++retiringCount;
        } else {
            slots.setProperty(index, "closed", false);
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
            if (route)
                extent = Math.max(extent, route.end.p[0] + 28);
        }
        if (targetWidth !== extent) {
            targetWidth = extent;
            layoutUntil = Math.max(layoutUntil, clock + reflowDuration);
        }
    }

    function reflow() {
        let moved = false;
        if (externalDeparture || (flight && flight.mode !== "orbit")) {
            pendingReflow = true;
            return;
        }
        pendingReflow = false;
        const kept = [];
        for (let i = 0; i < slots.count; ++i)
            kept.push(slots.get(i).workspaceId);
        kept.sort((a, b) => a - b);
        for (let i = 0; i < kept.length; ++i) {
            moved = positionBody(kept[i], 28 + i * stride) || moved;
        }
        if (moved)
            clearTrail();
        ++layoutRevision;
        updateWidth();
    }

    function pruneRetired() {
        let changed = false;
        for (let i = slots.count - 1; i >= 0; --i) {
            const body = slots.get(i);
            if (!body.live && !protectedBody(body.workspaceId) && (body.closed || !body.revealed)) {
                delete layoutRoutes[body.workspaceId];
                slots.remove(i);
                --retiringCount;
                changed = true;
            }
        }
        if (changed) {
            ++layoutRevision;
            reflow();
        }
    }

    function finishConcealment(id) {
        const index = slotFor(id);
        if (index >= 0 && !slots.get(index).live && !protectedBody(id))
            slots.setProperty(index, "closed", true);
    }

    function revealBody(id) {
        const index = slotFor(id);
        if (index >= 0 && !slots.get(index).revealed) {
            slots.setProperty(index, "revealed", true);
            ++layoutRevision;
        }
    }

    // The workspaces Hyprland reports, in id order.
    function observedWorkspaces() {
        return workspaces.filter(workspace => workspace && workspace.id > 0)
            .map(workspace => ({ workspaceId: workspace.id, label: String(workspace.name) }))
            .filter((workspace, index, list) => list.findIndex(other => other.workspaceId === workspace.workspaceId) === index)
            .sort((a, b) => a.workspaceId - b.workspaceId);
    }

    // The observed workspaces that may have a body now. A workspace without one
    // waits for the active workspace to settle and for its own settle delay, so
    // one that flickers in and out never grows a body.
    function admittedWorkspaces(observed, now) {
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
        return desired;
    }

    // Gives every desired workspace a body and retires the others. Returns
    // whether any body changed.
    function applyDesired(desired) {
        const desiredIds = new Set(desired.map(workspace => workspace.workspaceId));
        let changed = false;
        for (let i = 0; i < desired.length; ++i) {
            const index = slotFor(desired[i].workspaceId);
            if (index < 0) {
                slots.append({ workspaceId: desired[i].workspaceId, label: desired[i].label,
                    live: true, closed: false,
                    revealed: !flight || desired[i].workspaceId !== activeId, animatedEntry: !!flight });
                changed = true;
            } else {
                if (slots.get(index).label !== desired[i].label)
                    slots.setProperty(index, "label", desired[i].label);
                changed = setPresent(index, true) || changed;
                if (desired[i].workspaceId !== activeId && !protectedBody(desired[i].workspaceId))
                    revealBody(desired[i].workspaceId);
            }
        }
        for (let i = 0; i < slots.count; ++i) {
            if (!desiredIds.has(slots.get(i).workspaceId))
                changed = setPresent(i, false) || changed;
        }
        return changed;
    }

    // Starts the ship from the active workspace's body when there is no flight,
    // and aims it at the active workspace.
    function steerShip() {
        if (!Motion.finitePose(pose)) {
            const center = centerFor(activeId, false);
            if (!center)
                return;
            revealBody(activeId);
            flight = Flight.create(activeId, center);
            ++flightRevision;
            pose = flight.pose;
            heading = flight.heading;
        }
        if (flight)
            Flight.request(flight, activeId);
    }

    function synchronize() {
        if (!ready)
            return;
        const observed = observedWorkspaces();
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

        const desired = admittedWorkspaces(observed, now);
        if (applyDesired(desired))
            reflow();
        if (!desired.some(workspace => workspace.workspaceId === activeId))
            return;
        steerShip();
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
                    live: body.live, settled: clock >= Math.max(layoutUntil, route.started + route.duration) });
        }
        if (clock >= layoutUntil) {
            cachedBodies = bodies;
            cachedBodiesRevision = layoutRevision;
        }
        return bodies;
    }

    function clearTrail() {
        trailBuffer.clear(clock);
    }

    function screenPose(screen) {
        if (!Motion.finitePose(pose))
            return null;

        const point = mapToItem(null, pose.p[0], pose.p[1]);
        return {
            p: [screen.x + point.x, screen.y + point.y, pose.p[2]],
            v: pose.v.slice(),
            a: pose.a.slice()
        };
    }

    function departureState(screen) {
        if (!flight || flight.mode !== "orbit")
            return null;

        const center = centerFor(flight.orbitId, false);
        if (!center)
            return null;
        const point = mapToItem(null, center[0], center[1]);
        return {
            state: Object.assign({}, flight, {pose: screenPose(screen), heading: heading}),
            body: {id: flight.orbitId, center: [screen.x + point.x, screen.y + point.y], live: true, settled: true}
        };
    }

    function arrivalTarget(screen) {
        flight = null;
        pose = null;
        settledActiveId = activeId;
        synchronize();

        const center = centerFor(activeId, true);
        if (!center || slotFor(activeId) < 0)
            return null;

        revealBody(activeId);
        flight = Flight.create(activeId, center);
        pose = flight.pose;
        heading = flight.heading;

        const point = mapToItem(null, center[0], center[1]);
        return {id: activeId, center: [screen.x + point.x, screen.y + point.y], live: true, settled: true};
    }

    function acceptFlight(arrival) {
        const center = centerFor(arrival.orbitId, true);
        if (!center)
            return;

        flight = Flight.create(arrival.orbitId, center);
        flight.angle = arrival.angle;
        flight.direction = arrival.direction;
        flight.heading = arrival.heading;
        flight.pose = Motion.orbit(center, arrival.angle, arrival.direction * Motion.angularSpeed);

        pose = flight.pose;
        heading = flight.heading;
        ++flightRevision;
    }

    function displayDeparture(state, screen, seconds) {
        const point = mapFromItem(null, state.pose.p[0] - screen.x, state.pose.p[1] - screen.y);
        pose = Object.assign({}, state.pose, {p: [point.x, point.y, state.pose.p[2]]});
        heading = state.heading;
        throttle = state.throttle;
        braking = state.braking;

        clock += seconds;
        recordTrail();
    }

    function recordTrail() {
        if (layoutMoving)
            return;

        trailBuffer.record(pose, throttle, clock);
    }

    // Moves the clocks forward and finishes any reflow of the bodies.
    function advanceLayout(seconds) {
        clock += seconds;
        if (layoutClock < layoutUntil)
            layoutClock = Math.min(clock, layoutUntil);
        if (layoutMoving && clock >= layoutUntil) {
            layoutMoving = false;
            clearTrail();
        }
        if (retiringCount > 0)
            pruneRetired();
    }

    // Flies the ship for `dt` seconds, orbiting or heading for another body.
    function advanceShip(dt) {
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
        const previousMode = flight.mode;
        Flight.advance(flight, dt, bodies);
        if (previousMode === "orbit" && flight.mode === "departure")
            revealBody(flight.targetId);
        if (previousOrbitId !== flight.orbitId)
            revealBody(flight.orbitId);
        if (previousOrbitId !== flight.orbitId || previousMode !== flight.mode)
            ++flightRevision;
        pose = flight.pose;
        heading = flight.heading;
        throttle = flight.throttle;
        braking = flight.braking;
        if (previousOrbitId !== flight.orbitId || (pendingReflow && flight.mode === "orbit"))
            reflow();
        if (!Motion.finitePose(pose))
            return;
        recordTrail();
    }

    function advance(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return;
        advanceLayout(seconds);
        if (!shipActive)
            return;
        advanceShip(Math.min(seconds, 0.25));
    }

    function resetForMonitor() {
        activeSettle.stop();
        bodySettle.stop();
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
        ++flightRevision;
        pose = null;
        clearTrail();
        retiringCount = 0;
        wheelStepper.reset();
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
    onExternalDepartureChanged: {
        if (!externalDeparture && pendingReflow)
            reflow();
    }
    onShipActiveChanged: {
        clearTrail();
        if (shipActive && ready && !Motion.finitePose(pose)) {
            flight = null;
            pose = null;
            settledActiveId = activeId;
            synchronize();
        }
    }

    // Overlays open on the focused screen and cover the rocket, so the scene pauses
    // instead of competing with their animation for the GPU and the GUI thread.
    FrameAnimation {
        running: root.motionEnabled && !root.externalDeparture && root.visible && root.Window.window !== null
            && root.Window.window.visible && root.flight !== null && !OverlayController.active
        onTriggered: root.advance(frameTime)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: Theme.pillBackground
        opacity: Theme.pillOpacity
        z: -2
    }

    TrailLines {
        trail: trailBuffer
        shown: root.shipActive
    }

    Repeater {
        id: planets
        model: slots

        Planet {
            required property bool live
            required property bool revealed
            required property bool animatedEntry
            readonly property var position: root.layoutPose(workspaceId, root.layoutClock, root.layoutRevision)
            visible: position !== null
            x: position ? position.p[0] - width / 2 : 0
            expanded: revealed && (live || root.protectedBody(workspaceId, root.flightRevision))
            animateEntry: animatedEntry
            interactive: live
            selected: workspaceId === root.activeId
            z: 1
            onConcealed: root.finishConcealment(workspaceId)
            onActivated: root.workspaceRequested(workspaceId)
        }
    }

    TrailSparks {
        trail: trailBuffer
        shown: root.shipActive
    }

    OrbitalShip {
        visible: root.shipActive && root.pose !== null
        x: root.pose ? root.pose.p[0] - width / 2 : 0
        y: root.pose ? root.pose.p[1] - height / 2 : 0
        z: root.pose && root.pose.p[2] > 0 ? 3 : 0
        rotation: root.heading * 180 / Math.PI
        scale: root.pose ? 1.05 + Math.max(-1, Math.min(1, root.pose.p[2] / Motion.radiusZ)) * 0.04 : 1.05
        throttle: root.throttle
        braking: root.braking
        clock: root.clock
    }

    WheelStepper {
        id: wheelStepper

        anchors.fill: parent
        enabled: root.scrollEnabled
        onStepRequested: direction => root.wheelRequested(direction)
    }
}
