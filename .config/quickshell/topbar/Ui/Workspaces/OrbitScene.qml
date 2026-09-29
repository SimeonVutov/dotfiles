pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import "OrbitalMotion.js" as Motion
import "OrbitFlight.js" as Flight

Item {
    id: root

    property var workspaces: []
    property int activeId: -1
    property bool motionEnabled: true
    signal workspaceRequested(int workspaceId)
    signal wheelRequested(int direction)

    property var pose: null
    property var flight: null
    property bool pendingReflow: false
    property var layoutRoutes: ({})
    property int layoutRevision: 0
    property real targetWidth: 0
    property real heading: 0
    property real throttle: 0
    property real braking: 0
    property real clock: 0
    property int destinationId: -1
    property bool ready: false
    property var trailPoints: []
    property int trailHead: -1
    property real nextTrailAt: 0
    readonly property int stride: 48
    readonly property int trailCapacity: 32
    readonly property real revealDuration: 0.3

    implicitWidth: targetWidth
    implicitHeight: Theme.barHeight - Theme.pillMarginV * 2
    width: implicitWidth
    height: implicitHeight
    clip: true

    ListModel { id: slots }

    Behavior on implicitWidth {
        NumberAnimation { duration: 230; easing.type: Easing.InOutCubic }
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
            return;
        const start = previous ? layoutPose(id, clock) : end;
        layoutRoutes[id] = { axes: Motion.coefficients(start, end, 0.45), duration: previous ? 0.45 : 0, started: clock, end: end };
    }

    function revealFor(id, time) {
        const index = slotFor(id);
        if (index < 0)
            return 0;
        const body = slots.get(index);
        return body.exposureFrom + (body.exposureTo - body.exposureFrom) * Motion.ease((time - body.exposureAt) / revealDuration);
    }

    function setPresent(index, present) {
        const body = slots.get(index);
        const show = present || (body.workspaceId === destinationId && activeId > 0)
            || (flight && flight.mode !== "orbit" && flight.targetId === body.workspaceId);
        slots.setProperty(index, "live", present);
        if (body.exposureTo === (show ? 1 : 0))
            return;
        const exposure = revealFor(body.workspaceId, clock);
        slots.setProperty(index, "exposureFrom", exposure);
        slots.setProperty(index, "exposureTo", show ? 1 : 0);
        slots.setProperty(index, "exposureAt", clock);
    }

    function updateWidth() {
        let extent = 0;
        for (let i = 0; i < slots.count; ++i) {
            const route = layoutRoutes[slots.get(i).workspaceId];
            if (route)
                extent = Math.max(extent, route.end.p[0] + 28);
        }
        targetWidth = extent;
    }

    function reflow() {
        if (flight && flight.mode !== "orbit") {
            let extent = targetWidth;
            for (let i = 0; i < slots.count; ++i) {
                const id = slots.get(i).workspaceId;
                if (!layoutRoutes[id]) {
                    positionBody(id, extent + 20);
                    extent += stride;
                }
            }
            pendingReflow = true;
            ++layoutRevision;
            updateWidth();
            return;
        }
        pendingReflow = false;
        const ids = [];
        for (let i = 0; i < slots.count; ++i)
            ids.push(slots.get(i).workspaceId);
        ids.sort((a, b) => a - b);
        let liveIndex = 0;
        for (let i = 0; i < ids.length; ++i) {
            const index = slotFor(ids[i]);
            if (index !== i)
                slots.move(index, i, 1);
            if (slots.get(i).live || (ids[i] === destinationId && activeId > 0))
                positionBody(ids[i], 28 + liveIndex++ * stride);
        }
        ++layoutRevision;
        updateWidth();
    }

    function pruneRetired() {
        let changed = false;
        for (let i = slots.count - 1; i >= 0; --i) {
            const body = slots.get(i);
            if (!body.live)
                setPresent(i, false);
            if (!body.live && body.exposureTo === 0 && clock - body.exposureAt >= revealDuration) {
                delete layoutRoutes[body.workspaceId];
                slots.remove(i);
                changed = true;
            }
        }
        if (changed)
            reflow();
    }

    function synchronize() {
        if (!ready)
            return;
        const desired = workspaces.filter(workspace => workspace && workspace.id > 0)
            .map(workspace => ({ workspaceId: workspace.id, label: String(workspace.name) }))
            .filter((workspace, index, list) => list.findIndex(other => other.workspaceId === workspace.workspaceId) === index)
            .sort((a, b) => a.workspaceId - b.workspaceId);
        for (let i = 0; i < desired.length; ++i) {
            const index = slotFor(desired[i].workspaceId);
            if (index < 0) {
                slots.append({ workspaceId: desired[i].workspaceId, label: desired[i].label,
                    live: true, exposureFrom: 0, exposureTo: 1, exposureAt: clock });
            } else {
                slots.setProperty(index, "label", desired[i].label);
                setPresent(index, true);
            }
        }
        for (let i = 0; i < slots.count; ++i) {
            if (!desired.some(workspace => workspace.workspaceId === slots.get(i).workspaceId))
                setPresent(i, false);
        }
        reflow();
        if (!desired.some(workspace => workspace.workspaceId === activeId))
            return;
        if (!Motion.finitePose(pose)) {
            destinationId = activeId;
            flight = Flight.create(activeId, centerFor(activeId, false));
            pose = flight.pose;
            heading = flight.heading;
        }
        Flight.request(flight, activeId);
    }

    function flightBodies() {
        const bodies = [];
        for (let i = 0; i < slots.count; ++i) {
            const body = slots.get(i);
            const route = layoutRoutes[body.workspaceId];
            if (route)
                bodies.push({ id: body.workspaceId, center: centerFor(body.workspaceId, false),
                    live: body.live, settled: clock >= route.started + route.duration });
        }
        return bodies;
    }

    function trailPoint(ageIndex) {
        return trailHead < 0 ? null : trailPoints[(trailHead - ageIndex + trailCapacity) % trailCapacity] || null;
    }

    function advance(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return;
        const dt = Math.min(seconds, 0.1);
        clock += dt;
        pruneRetired();
        if (slots.count === 0) {
            pose = null;
            flight = null;
            destinationId = -1;
            trailPoints = [];
            trailHead = -1;
            return;
        }
        if (!Motion.finitePose(pose)) {
            synchronize();
            if (!Motion.finitePose(pose))
                return;
        }
        Flight.request(flight, activeId);
        Flight.advance(flight, dt, flightBodies());
        pose = flight.pose;
        heading = flight.heading;
        throttle = flight.throttle;
        braking = flight.braking;
        destinationId = flight.orbitId;
        if (pendingReflow && flight.mode === "orbit")
            reflow();
        if (!Motion.finitePose(pose))
            return;
        if (clock >= nextTrailAt) {
            trailHead = (trailHead + 1) % trailCapacity;
            trailPoints[trailHead] = { x: pose.p[0], y: pose.p[1], z: pose.p[2], heat: throttle, time: clock };
            nextTrailAt = clock + 0.025;
        }
    }

    Component.onCompleted: {
        ready = true;
        synchronize();
    }
    onWorkspacesChanged: synchronize()
    onActiveIdChanged: synchronize()

    FrameAnimation {
        running: root.motionEnabled && root.visible && root.Window.window !== null
            && root.Window.window.visible && slots.count > 0
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
            readonly property real age: head ? root.clock - head.time : 2
            x: head ? head.x : 0
            y: head ? head.y - height / 2 : 0
            width: head && tail ? Math.hypot(tail.x - head.x, tail.y - head.y) + 0.25 : 0
            height: 0.8
            radius: 0.4
            transformOrigin: Item.Left
            rotation: head && tail ? Math.atan2(tail.y - head.y, tail.x - head.x) * 180 / Math.PI : 0
            color: head && head.heat > 0.25 ? "#E8C59B" : "#FFFFFF"
            opacity: Math.max(0, 1 - age / 0.8) * 0.35
            visible: head !== null && tail !== null && opacity > 0
            z: head && head.z > 0 ? 2 : 0
        }
    }

    Repeater {
        id: planets
        model: slots

        Planet {
            required property bool live
            readonly property var position: root.layoutPose(workspaceId, root.clock, root.layoutRevision)
            presence: root.revealFor(workspaceId, root.clock)
            x: position ? position.p[0] - width / 2 + (1 - presence) * (live ? -18 : 18) : 0
            interactive: live
            selected: workspaceId === root.activeId
            z: 1
            onActivated: root.workspaceRequested(workspaceId)
        }
    }

    Repeater {
        model: 8

        Rectangle {
            required property int index
            readonly property var point: root.trailPoint(index * 3)
            readonly property real age: point ? root.clock - point.time : 2
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
        onWheel: wheel => root.wheelRequested(wheel.angleDelta.y > 0 ? -1 : 1)
    }
}
