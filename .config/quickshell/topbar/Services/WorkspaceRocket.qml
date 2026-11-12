pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Ui.Workspaces
import "../Ui/Workspaces/OrbitFlight.js" as Flight
import "../Ui/Workspaces/OrbitalMotion.js" as Motion

Singleton {
    id: root

    property string focusedMonitor: Hyprland.focusedMonitor?.name || ""
    property string monitorName: ""
    property var scenes: ({})
    property var transfer: null
    property var bodies: []
    property string destination: ""
    property int destinationId: -1
    property var pose: null
    property real heading: 0
    property real elapsed: 0
    property var trailPoints: []
    property int trailRevision: 0
    property real trailOpacity: 1
    property string stage: "idle"
    property string departureMonitor: ""
    readonly property bool travelling: transfer !== null

    function registerScene(name, scene, screen) {
        scenes[name] = {scene: scene, screen: screen};
        Qt.callLater(followFocus);
    }

    function unregisterScene(name, scene) {
        if (scenes[name]?.scene === scene)
            delete scenes[name];
        Qt.callLater(followFocus);
    }

    function followFocus() {
        if (!focusedMonitor) {
            retry.stop();
            fade.stop();
            if (scenes[departureMonitor])
                scenes[departureMonitor].scene.externalDeparture = false;
            stage = "idle";
            transfer = null;
            monitorName = "";
            trailPoints = [];
            ++trailRevision;
            return;
        }
        if (!monitorName && !travelling) {
            monitorName = focusedMonitor;
            return;
        }
        if (!travelling && focusedMonitor === monitorName)
            return;
        // Keep a committed flight intact. followFocus runs again after capture
        // and reads the latest request, so rapid switches cannot restart the curve.
        if (travelling && stage === "transfer")
            return;
        if (travelling && focusedMonitor === departureMonitor) {
            destination = departureMonitor;
            destinationId = transfer.orbitId;
            Flight.request(transfer, destinationId);
            return;
        }

        const target = scenes[focusedMonitor];
        if (!target)
            return;
        const arrival = target.scene.arrivalTarget(target.screen);
        const previous = bodies.find(body => body.id === destinationId);
        if (travelling && destination === focusedMonitor && destinationId === arrival?.id
                && previous?.center[0] === arrival.center[0] && previous?.center[1] === arrival.center[1])
            return;
        const source = scenes[monitorName];
        const departure = travelling ? null : source?.scene.departureState(source.screen);
        if (!arrival || (!travelling && source && !departure)) {
            retry.restart();
            return;
        }
        if (!travelling && !departure) {
            monitorName = focusedMonitor;
            return;
        }

        fade.stop();
        if (!travelling) {
            bodies = [departure.body];
            elapsed = 0;
            trailPoints = [];
            pose = departure.state.pose;
            heading = departure.state.heading;
            departureMonitor = monitorName;
            source.scene.externalDeparture = true;
            stage = "departure";
            transfer = Object.assign({}, departure.state, {outerTransfers: true});
        }
        bodies = bodies.filter(body => body.id === transfer.orbitId).concat([arrival]);
        destination = focusedMonitor;
        destinationId = arrival.id;
        trailOpacity = 1;
        Flight.request(transfer, destinationId);
    }

    function shapeRoute(route) {
        const start = Motion.orbit(route.source, route.departureAngle, route.departureDirection * Motion.angularSpeed);
        const end = Motion.orbit(route.destination, route.arrivalAngle, route.direction * Motion.angularSpeed);
        const distance = Math.hypot(end.p[0] - start.p[0], end.p[1] - start.p[1]);
        route.duration = Math.max(.85, Math.min(1.4, distance / 1800));

        // Long tangent handles shape the curve; a separate timing curve preserves orbital speed at both ends.
        const length = Math.max(1, distance * .35, Math.hypot(start.v[0], start.v[1]) * route.duration / 3);
        const startSpeed = Math.max(.01, Math.hypot(start.v[0], start.v[1]));
        const endSpeed = Math.hypot(end.v[0], end.v[1]);
        const controls = [start.p, start.p.map((value, i) => value + start.v[i] / startSpeed * length),
            end.p.map((value, i) => value - end.v[i] / endSpeed * length), end.p];

        const timingStart = {p: [0, 0, 0], v: [startSpeed / (3 * length), 0, 0], a: [0, 0, 0]};
        const timingEnd = {p: [1, 0, 0], v: [endSpeed / (3 * length), 0, 0], a: [0, 0, 0]};
        const sign = end.p[0] >= start.p[0] ? 1 : -1;
        route.curve = {
            axes: Motion.coefficients(timingStart, timingEnd, route.duration),
            controls: controls,
            duration: route.duration,
            arc: Math.min(180, distance * .15),
            normal: [-(end.p[1] - start.p[1]) / Math.max(1, distance) * sign,
                (end.p[0] - start.p[0]) / Math.max(1, distance) * sign, 0]
        };
    }

    function advance(seconds) {
        const dt = Math.min(seconds, .1);
        if (dt <= 0 || !transfer)
            return;
        elapsed += dt;
        Flight.advance(transfer, dt, bodies);
        const route = transfer.plan?.route;
        if (route && !route.curve)
            shapeRoute(route);

        pose = transfer.pose;
        heading = transfer.heading;
        if (stage === "departure") {
            const source = scenes[departureMonitor];
            if (transfer.mode === "transfer" || !source) {
                stage = "transfer";
                if (source)
                    source.scene.externalDeparture = false;
            } else {
                // Keep the original scene's depth ordering and orbital trail until takeoff.
                source.scene.displayDeparture(transfer, source.screen, dt);
            }
        }
        if (stage === "transfer")
            trailPoints.push({x: pose.p[0], y: pose.p[1], time: elapsed});
        while (trailPoints.length > 100 || (trailPoints.length > 1 && elapsed - trailPoints[0].time > .65))
            trailPoints.shift();
        ++trailRevision;

        if (transfer.mode === "orbit" && transfer.orbitId === destinationId) {
            const target = scenes[destination];
            if (target)
                target.scene.acceptFlight(transfer);
            const source = scenes[departureMonitor];
            if (source)
                source.scene.externalDeparture = false;
            monitorName = destination;
            stage = "idle";
            transfer = null;
            fade.start();
            Qt.callLater(followFocus);
        }
    }

    onFocusedMonitorChanged: Qt.callLater(followFocus)
    Component.onCompleted: Qt.callLater(followFocus)

    Timer {
        id: retry
        interval: 40
        onTriggered: root.followFocus()
    }

    FrameAnimation {
        running: root.travelling
        onTriggered: root.advance(frameTime)
    }

    NumberAnimation {
        id: fade
        target: root
        property: "trailOpacity"
        to: 0
        duration: 350
        onFinished: {
            root.trailPoints = [];
            ++root.trailRevision;
        }
    }

    LazyLoader {
        active: root.travelling || root.trailPoints.length > 0
        component: WorkspaceFlightOverlay { coordinator: root }
    }
}
