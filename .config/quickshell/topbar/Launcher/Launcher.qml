import QtQuick
import Quickshell
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
    property real progress: 0
    property alias query: searchConsole.query

    // The globe stops growing past this viewport; smaller screens scale it down.
    readonly property real referenceViewportWidth: 600
    readonly property real referenceViewportHeight: 500
    readonly property real globeScale: Math.min(1, width / referenceViewportWidth, height / referenceViewportHeight)
    readonly property real globeRadius: Theme.globeRadius * globeScale

    // The entrance only begins revealing the scene at its halfway point.
    readonly property real revealFrom: .5
    readonly property real reveal: Math.max(0, Math.min(1, (progress - revealFrom) / (1 - revealFrom)))
    readonly property real settled: 1 - Math.pow(1 - reveal, 3)

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
            centerRadius: root.globeRadius + root.globeClearance
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
        dismissAfterFrame.stop();
        progress = 0;
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

    function cancel() {
        if (closing) {
            pendingLaunch = null;
            if (delivery.running) {
                delivery.stop();
                beginDescent();
            }
            return;
        }
        closing = true;
        beginDescent();
    }

    function beginDescent() {
        ascent.stop();
        descent.from = progress;
        descent.duration = Math.max(1, ascent.duration * progress);
        descent.start();
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
        delivery.start();
    }

    function launchSelected() {
        activate(highlightedApp);
    }

    function launchFailed(message) {
        pendingLaunch = null;
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
        onFinished: root.beginDescent()
    }

    NumberAnimation {
        id: descent
        target: root
        property: "progress"
        to: 0
        easing.type: Easing.Linear
        onFinished: dismissAfterFrame.start()
    }

    Timer {
        id: dismissAfterFrame
        interval: Theme.settleDelay
        onTriggered: {
            const app = root.pendingLaunch;
            root.pendingLaunch = null;
            if (app && root.catalog.includes(app))
                root.launchRequested(app);
            else
                root.dismissed();
        }
    }

    Ascent {
        anchors.fill: parent
        progress: root.progress
        snapshot: root.snapshot
        onSnapshotReady: root.snapshotReady()
    }

    Item {
        id: scene

        anchors.fill: parent
        enabled: !root.closing

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

        Repeater {
            id: satellites

            model: root.catalog

            Satellite {
                required property int index

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
                tracking: root.beamsEnabled
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

    DeliveryFlight {
        anchors.fill: parent
        launching: root.pendingLaunch !== null
        sceneVisible: root.closing && root.progress > root.revealFrom
        progress: root.flightProgress
        settled: root.settled
        origin: root.deliveryOrigin
        destination: root.deliveryDestination
        startSize: root.flightSize
        icon: root.flightIcon
        label: root.flightLabel
    }
}
