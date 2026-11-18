import QtQuick
import Quickshell
import "Flight.js" as Flight
import "Scatter.js" as Scatter
import "Search.js" as Search

FocusScope {
    id: root

    signal dismissed
    signal launchRequested(var entry)
    signal snapshotReady

    property var applications: DesktopEntries.applications.values
    property var settledApplications: []
    readonly property int catalogFallbackDelay: 250
    property string snapshot: ""
    property bool presenting: true
    property alias query: searchConsole.query

    // The flight (Flight.js). The entrance runs `progress` from 0 to 1. Closing
    // runs `closeProgress` as a landing (cancelled in orbit), an abort (cancelled
    // during lift-off) or an exit (an app was chosen), starting from the state
    // the flight was in when it began.
    property real progress: 0
    property string closeMode: ""
    property real closeProgress: 0
    property var closeFrom: null
    property real closeClock: 0
    // Fades the whole launcher when a landing is skipped with a second cancel.
    property real fade: 1

    // The globe stops growing past this viewport; smaller screens scale it down.
    readonly property real referenceViewportWidth: 600
    readonly property real referenceViewportHeight: 500
    readonly property real globeScale: Math.min(1, width / referenceViewportWidth, height / referenceViewportHeight)
    readonly property real globeRadius: Theme.globeRadius * globeScale

    readonly property real aspect: width / Math.max(1, height)
    readonly property var flight: Flight.state(closeMode, progress, closeProgress, closeFrom, aspect, globeRadius / Math.max(1, height))
    readonly property real clock: closeMode ? closeClock + closeProgress * descent.duration / 1000 : progress * Theme.entranceDuration / 1000
    readonly property real settled: 1 - Math.pow(1 - flight.reveal, 3)
    // Early in lift-off, behind the shaking and smoke, everything shown later
    // is drawn once, invisibly, so its shaders, icons and textures are ready
    // before it appears instead of stalling the moment it does.
    readonly property bool warming: !closing && progress > Theme.warmFrom && progress < Theme.warmUntil
    // The capsule's window during a landing: centre and half size, in screen heights.
    readonly property rect pane: Qt.rect(aspect / 2, .5, aspect / 2 * Theme.paneWidth * flight.frameZoom,
        .5 * Theme.paneHeight * flight.frameZoom)

    // Camera shake, in screen heights: a few unrelated frequencies read as rumble.
    readonly property point shake: Qt.point(
        flight.shake * (Math.sin(clock * 83) * .55 + Math.sin(clock * 137 + 1.3) * .3 + Math.sin(clock * 47 + .4) * .25),
        flight.shake * (Math.sin(clock * 97 + 2.1) * .5 + Math.sin(clock * 151 + .7) * .3 + Math.sin(clock * 59 + 1.9) * .3))

    readonly property var catalog: settledApplications.filter(a => !a.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name))
    readonly property var results: Search.rank(catalog, query)
    // Tested per satellite on every pointer move, so keep membership O(1).
    readonly property var resultSet: new Set(results)

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
        ascent.stop();
        delivery.stop();
        descent.stop();
        skipFade.stop();
        dismissAfterFrame.stop();
        progress = 0;
        closeMode = "";
        closeProgress = 0;
        closeFrom = null;
        fade = 1;
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
                skip();
            return;
        }
        if (closeMode === "exit")
            return;

        pendingLaunch = null;
        delivery.stop();
        closing = true;
        beginClose(progress < Theme.abortBefore ? "abort" : "landing");
    }

    function beginClose(mode) {
        ascent.stop();
        closeFrom = flight;
        closeClock = clock;
        closeProgress = 0;
        descent.duration = mode === "landing" ? Theme.landingDuration : mode === "exit" ? Theme.exitDuration : Theme.abortDuration;
        closeMode = mode;
        descent.restart();
    }

    function skip() {
        if (!skipFade.running)
            skipFade.start();
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
            beginClose("exit");
    }

    function launchSelected() {
        activate(highlightedApp);
    }

    function launchFailed(message) {
        pendingLaunch = null;
        descent.stop();
        closeMode = "";
        closeProgress = 0;
        closeFrom = null;
        closing = false;
        progress = 1;
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
    onApplicationsChanged: catalogRefresh.restart()
    onCatalogChanged: scheduleLayout()
    onWidthChanged: scheduleLayout()
    onHeightChanged: scheduleLayout()
    onPresentingChanged: if (presenting) {
        ascent.restart();
        Qt.callLater(focusSearch);
    }
    Component.onCompleted: {
        catalogRefresh.restart();
        scheduleLayout();
        if (presenting)
            ascent.start();
        Qt.callLater(focusSearch);
    }

    // DesktopEntries signals once after its per-entry model updates.
    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            catalogRefresh.stop();
            root.settledApplications = root.applications.slice();
        }
    }

    // Also handles application lists supplied by previews and tests.
    Timer {
        id: catalogRefresh

        interval: root.catalogFallbackDelay
        onTriggered: root.settledApplications = root.applications.slice()
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.presenting
        onActivated: root.cancel()
    }

    NumberAnimation {
        id: ascent
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Theme.entranceDuration
        easing.type: Easing.Linear
        onFinished: root.beamsEnabled = true
    }

    NumberAnimation {
        id: delivery
        target: root
        property: "flightProgress"
        from: 0
        to: 1
        duration: Theme.deliveryDuration
        easing.type: Easing.InOutCubic
        onFinished: root.beginClose("exit")
    }

    NumberAnimation {
        id: descent
        target: root
        property: "closeProgress"
        from: 0
        to: 1
        easing.type: Easing.Linear
        onFinished: dismissAfterFrame.start()
    }

    NumberAnimation {
        id: skipFade
        target: root
        property: "fade"
        to: 0
        duration: Theme.skipDuration
        easing.type: Easing.OutCubic
        onFinished: {
            descent.stop();
            root.finishClose();
        }
    }

    // Keeps the settled closing frame visible before the overlay unmaps.
    Timer {
        id: dismissAfterFrame
        interval: Theme.settleDelay
        onTriggered: root.finishClose()
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

    // Deep space behind everything; without a capture it fades in with altitude
    // so the real desktop is not covered before the flight starts.
    Rectangle {
        anchors.fill: parent
        color: Theme.space
        opacity: root.captureReady ? 1 : Math.min(1, root.progress * 3)
    }

    Starfield {
        x: -Theme.shakeMargin
        y: -Theme.shakeMargin
        width: parent.width + Theme.shakeMargin * 2
        height: parent.height + Theme.shakeMargin * 2
        level: root.flight.stars
        streak: root.flight.starsStreak
        shift: root.flight.starsShift
        transform: [
            Scale {
                origin.x: root.width / 2 + Theme.shakeMargin
                origin.y: root.height / 2 + Theme.shakeMargin
                xScale: root.flight.starsZoom
                yScale: root.flight.starsZoom
            },
            Translate {
                x: root.shake.x * root.height
                y: root.shake.y * root.height
            }
        ]
    }

    World {
        flight: root.flight
        surface: capture
        hasSurface: root.captureReady ? 1 : 0
        clock: root.clock
        shake: root.shake
    }

    Smoke {
        anchors.fill: parent
        flight: root.flight
        clock: root.clock
        shake: root.shake
        pane: root.pane
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
