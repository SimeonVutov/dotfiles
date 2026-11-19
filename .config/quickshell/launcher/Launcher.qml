import QtQuick
import "Scatter.js" as Scatter

FocusScope {
    id: root

    signal dismissed
    signal launchRequested(var entry)
    signal snapshotReady

    property alias applications: appCatalog.applications
    property alias settledApplications: appCatalog.settledApplications
    property string snapshot: ""
    property bool presenting: true
    property alias query: searchConsole.query

    // The flight (FlightTimeline) and its state at this moment.
    property alias progress: timeline.progress
    property alias closeMode: timeline.closeMode
    property alias closeProgress: timeline.closeProgress
    property alias closeFrom: timeline.closeFrom
    property alias closeClock: timeline.closeClock
    property alias fade: timeline.fade

    // The globe stops growing past this viewport; smaller screens scale it down.
    readonly property real referenceViewportWidth: 600
    readonly property real referenceViewportHeight: 500
    readonly property real globeScale: Math.min(1, width / referenceViewportWidth, height / referenceViewportHeight)
    readonly property real globeRadius: Theme.globeRadius * globeScale

    readonly property real aspect: width / Math.max(1, height)
    readonly property alias flight: timeline.flight
    readonly property alias clock: timeline.clock
    readonly property alias settled: timeline.settled
    readonly property alias warming: timeline.warming
    readonly property alias pane: timeline.pane
    readonly property alias shake: timeline.shake

    readonly property alias catalog: appCatalog.catalog
    readonly property alias results: appCatalog.results
    readonly property alias resultSet: appCatalog.resultSet

    // Space one satellite reserves: its craft, the box it drifts through, and
    // clearance for the label and hover growth.
    readonly property real packingHalfWidth: (Theme.craftWidth + Theme.craftDriftX) / 2 + Theme.craftClearanceX
    readonly property real packingHalfHeight: (Theme.craftHeight + Theme.craftDriftY) / 2 + Theme.craftClearanceY
    readonly property real globeClearance: 8
    readonly property var scatterOptions: ({
            itemHalfWidth: root.packingHalfWidth,
            itemHalfHeight: root.packingHalfHeight,
            // Keep satellites clear of the planet and the search capsule in front of it.
            centerRadius: Math.max(root.globeRadius, searchConsole.reach * root.globeScale) + root.globeClearance
        })
    property var layout: Scatter.emptyLayout(1)
    property bool layoutPending: false

    property int selectedIndex: 0
    property var pointerApp: null
    property bool mouseSelection: false
    property string launchError: ""
    readonly property real pointerSettle: .5
    readonly property real presenceFloor: .1
    readonly property var highlightedApp: pendingLaunch || (mouseSelection ? pointerApp : results[selectedIndex])
    readonly property string statusText: launchError || (results.length ? results.length + " available" : "No matches")

    property bool closing: false
    property bool beamsEnabled: false
    // The radio links' shared clock, running only while links can show, and
    // their brightness: the fewer satellites match, the stronger each link.
    property real linkClock: 0
    property int linkEpoch: 0
    readonly property real linkStrength: Math.min(1, 6 / Math.max(1, results.length))

    NumberAnimation on linkClock {
        from: 0
        to: 3600
        duration: 3600000
        loops: Animation.Infinite
        running: root.presenting && root.beamsEnabled
    }

    property var pendingLaunch: null
    property real flightProgress: 0
    property var flightSatellite: null
    property point flightStart: Qt.point(0, 0)
    property real flightSize: Theme.iconSize
    property string flightIcon: ""
    property string flightLabel: ""
    readonly property point deliveryOrigin: flightSatellite ? flightSatellite.iconPosition() : flightStart
    readonly property point deliveryDestination: flightSatellite ? flightSatellite.beamOrigin() : Qt.point(width / 2, height / 2)

    function prepare() {
        delivery.stop();
        timeline.reset();
        flightProgress = 0;
        pendingLaunch = null;
        flightSatellite = null;
        closing = false;
        beamsEnabled = false;
        query = "";
        selectedIndex = 0;
        pointerApp = null;
        mouseSelection = false;
        snapshot = "";
        launchError = "";
        regenerateLayout();
        linkClock = 0;
        linkEpoch++;
    }

    function regenerateLayout() {
        layoutPending = false;
        layout = Scatter.create(catalog.length, width, height, scatterOptions);
    }

    // Width, height and catalog can all change in one pass; scatter once after.
    function scheduleLayout() {
        if (layoutPending)
            return;
        layoutPending = true;
        Qt.callLater(regenerateLayout);
    }

    function focusSearch() {
        if (!closing)
            searchConsole.focusInput();
    }

    // A second cancel while landing skips the rest of it. The first moments
    // are ignored, so one key press that reaches both handlers counts once.
    function cancel() {
        if (closeMode === "landing" || closeMode === "abort") {
            if (closeProgress > Theme.skipAfter)
                timeline.skip();
            return;
        }
        if (closeMode === "exit")
            return;

        pendingLaunch = null;
        delivery.stop();
        closing = true;
        timeline.beginClose(progress < Theme.abortBefore ? "abort" : "landing");
    }

    function finishClose() {
        const app = root.pendingLaunch;
        root.pendingLaunch = null;
        if (app && root.catalog.includes(app))
            root.launchRequested(app);
        else
            root.dismissed();
    }

    function activate(entry) {
        if (closing || !entry || !results.includes(entry))
            return;
        pendingLaunch = entry;
        flightIcon = entry.icon || "";
        flightLabel = entry.name;
        const satellite = satellites.itemAt(catalog.indexOf(entry));
        flightSatellite = satellite;
        flightStart = satellite ? satellite.iconPosition() : Qt.point(width / 2, height / 2);
        flightSize = satellite ? Theme.iconSize * satellite.visualScale : Theme.iconSize;
        closing = true;
        // The icon flies down its beam only once the satellites are out.
        if (settled > .99)
            delivery.start();
        else
            timeline.beginClose("exit");
    }

    function launchSelected() {
        activate(highlightedApp);
    }

    function launchFailed(message) {
        pendingLaunch = null;
        closing = false;
        timeline.abandonClose();
        flightProgress = 0;
        launchError = message;
        Qt.callLater(focusSearch);
    }

    function moveSelection(delta) {
        const pointerIndex = results.indexOf(pointerApp);
        if (mouseSelection && pointerIndex >= 0)
            selectedIndex = pointerIndex;
        mouseSelection = false;
        if (!results.length)
            return;
        selectedIndex = (selectedIndex + delta + results.length) % results.length;
    }

    function moveSelectionInDirection(dx, dy) {
        if (closing || !results.length)
            return;

        const current = highlightedApp || results[0];
        selectedIndex = results.indexOf(current);
        mouseSelection = false;
        const origin = satellites.itemAt(catalog.indexOf(current));
        if (!origin)
            return;

        const position = origin.iconPosition();
        const nearest = nearestAppAt(position.x, position.y, dx, dy);
        if (nearest)
            selectedIndex = results.indexOf(nearest);
    }

    function pickable(satellite) {
        return satellite && satellite.accepted && satellite.visible && satellite.presence >= presenceFloor && resultSet.has(satellite.entry);
    }

    function nearestAppAt(x, y, directionX = 0, directionY = 0) {
        let nearest = null;
        let nearestDistance = Infinity;
        for (let i = 0; i < satellites.count; i++) {
            const satellite = satellites.itemAt(i);
            if (!pickable(satellite))
                continue;
            const candidate = satellite.iconPosition();
            const offsetX = candidate.x - x;
            const offsetY = candidate.y - y;
            if ((directionX || directionY) && offsetX * directionX + offsetY * directionY <= 0)
                continue;
            const distance = offsetX * offsetX + offsetY * offsetY;
            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearest = satellite.entry;
            }
        }
        return nearest;
    }

    function pickNearest(x, y) {
        if (closing || settled < pointerSettle)
            return;
        mouseSelection = true;
        pointerApp = nearestAppAt(x, y);
    }

    focus: true
    opacity: fade

    onResultsChanged: {
        mouseSelection = false;
        pointerApp = null;
        selectedIndex = 0;
        launchError = "";
    }
    onCatalogChanged: scheduleLayout()
    onWidthChanged: scheduleLayout()
    onHeightChanged: scheduleLayout()
    onPresentingChanged: if (presenting) {
        timeline.restart();
        Qt.callLater(focusSearch);
    }
    Component.onCompleted: {
        scheduleLayout();
        if (presenting)
            timeline.start();
        Qt.callLater(focusSearch);
    }

    FlightTimeline {
        id: timeline

        aspect: root.aspect
        radius: root.globeRadius / Math.max(1, root.height)
        closing: root.closing
        onAscended: root.beamsEnabled = true
        onClosed: root.finishClose()
    }

    AppCatalog {
        id: appCatalog

        query: root.query
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.presenting
        onActivated: root.cancel()
    }

    NumberAnimation {
        id: delivery
        target: root
        property: "flightProgress"
        from: 0
        to: 1
        duration: Theme.deliveryDuration
        easing.type: Easing.InOutCubic
        onFinished: timeline.beginClose("exit")
    }

    // The desktop capture: the ground at lift-off and the globe's surface.
    Image {
        id: capture

        source: root.snapshot
        visible: false
        cache: false
        mipmap: true
        // Synchronous: arming waits on Image.Ready, so a background decode would
        // race the open watchdog and drop the capture.
        asynchronous: false
        // Read status directly: a binding on it may not have updated yet inside
        // this handler, which left the launcher waiting for its watchdog.
        onStatusChanged: if (status === Image.Ready)
            root.snapshotReady()
    }

    readonly property bool captureReady: capture.status === Image.Ready

    FlightBackdrop {
        anchors.fill: parent
        flight: root.flight
        clock: root.clock
        shake: root.shake
        pane: root.pane
        surface: capture
        surfaceReady: root.captureReady
        progress: root.progress
    }

    Item {
        id: scene

        anchors.fill: parent
        enabled: !root.closing
        opacity: root.flight.ui
        visible: opacity > 0 && (root.settled > 0 || root.warming)

        SearchConsole {
            id: searchConsole

            z: 3
            anchors.centerIn: parent
            globeScale: root.globeScale
            settled: root.settled
            statusText: root.statusText
            onCancelled: root.cancel()
            onSubmitted: root.launchSelected()
            onMoved: delta => root.moveSelection(delta)
            onMovedInDirection: (dx, dy) => root.moveSelectionInDirection(dx, dy)
        }

        // Every satellite draws its craft from one of these two shared textures
        // (gold or silver foil).
        SatelliteArt {
            id: goldArt
        }

        SatelliteArt {
            id: silverArt

            silver: true
        }

        CraftTexture {
            id: goldCraft

            sourceItem: goldArt
            layoutScale: root.layout.scale
        }

        CraftTexture {
            id: silverCraft

            sourceItem: silverArt
            layoutScale: root.layout.scale
        }

        IconCatalog {
            id: icons

            names: root.catalog.map(app => app.icon)
            idle: root.settled > .99 && !root.closing
        }

        Repeater {
            id: satellites

            model: root.catalog

            Satellite {
                required property int index

                // About one in three wears silver foil.
                craftTexture: index % 3 === 1 ? silverCraft : goldCraft
                craftArtMargin: goldCraft.margin

                slot: index
                entry: root.catalog[index]
                iconSource: icons.source(entry?.icon)
                active: root.resultSet.has(entry)
                basePosition: root.layout.points[index] || Qt.point(0, 0)
                visible: root.layout.points.length === root.catalog.length
                visualScale: root.layout.scale
                globeRadius: root.globeRadius
                width: scene.width
                height: scene.height
                arrival: root.settled
                warming: root.warming
                tracking: root.beamsEnabled
                linkClock: root.linkClock
                linkEpoch: root.linkEpoch
                linkStrength: root.linkStrength
                selected: entry !== null && entry === root.highlightedApp
                departing: root.pendingLaunch !== null && entry === root.pendingLaunch
            }
        }

        // The whole field targets the nearest satellite, so small badges remain easy to click.
        MouseArea {
            id: proximity
            objectName: "proximityArea"

            z: 2
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: root.mouseSelection && root.pointerApp ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                root.pickNearest(mouseX, mouseY);
                if (root.pointerApp)
                    root.activate(root.pointerApp);
                else
                    root.focusSearch();
            }
        }

        MouseArea {
            z: 4
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: root.mouseSelection && root.pointerApp ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPositionChanged: root.pickNearest(mouseX, mouseY)
        }
    }

    Cockpit {
        flight: root.flight
        pane: root.pane
        clock: root.clock
        warming: root.warming
    }

    // The touchdown's flash.
    Rectangle {
        anchors.fill: parent
        color: Theme.flash
        opacity: root.flight.flash * .35
        visible: opacity > 0
    }

    DeliveryFlight {
        anchors.fill: parent
        launching: root.pendingLaunch !== null
        sceneVisible: root.closing && root.settled > .99
        progress: root.flightProgress
        settled: root.settled
        origin: root.deliveryOrigin
        destination: root.deliveryDestination
        startSize: root.flightSize
        icon: root.flightIcon
        label: root.flightLabel
    }
}
