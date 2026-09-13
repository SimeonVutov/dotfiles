pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell:wallpaper-picker"
    visible: false
    color: "transparent"

    readonly property string home: Quickshell.env("HOME")
    readonly property string applyScript: home + "/.config/scripts/wallpaper-apply.sh"
    readonly property string paletteScript: home + "/.config/scripts/wallpaper-palette.sh"
    readonly property string indexScript: home + "/.config/scripts/wallpaper-index-json.py"

    QtObject {
        id: cardAppearance
        readonly property int cardWidth: 400
        readonly property int cardHeight: 420
        readonly property real expandedCardWidth: cardWidth * 1.5
        readonly property real collapsedCardWidth: cardWidth * 0.5
        readonly property int expandedCardHeight: cardHeight + 30
        readonly property int cardSpacing: 10
        readonly property int borderWidth: 3
        readonly property real skewFactor: -0.35
        readonly property int cardTransitionDuration: 260
        readonly property int cardFadeDuration: 220
        readonly property int thumbnailMinWidth: 900
        readonly property int thumbnailMinHeight: 540
        readonly property real thumbnailResolutionScale: 1.35
        readonly property int thumbnailOverscan: 80
        readonly property color placeholderBackdrop: "#0d0d0d"
        readonly property color badgeScrim: "#99000000"
        readonly property color appliedBadgeInk: "#10131a"
        readonly property color nameplateScrim: "#cc000000"
    }

    readonly property int controlTransitionDuration: 180
    readonly property int swatchTransitionDuration: 140
    readonly property int warningOnDuration: 120
    readonly property int warningOffDuration: 180

    readonly property string wallpaperFocus: "wallpapers"
    readonly property string paletteFocus: "palette"

    // Ad-hoc UI colors (badges, scrims, placeholders) not from the Catppuccin palette.
    readonly property color swatchHighlight: "#ffffff"
    readonly property color autoBadgeBackground: "#111111"

    property string currentWallpaper: ""
    property string currentFilter: "All"
    property bool initialFocusSet: false
    property bool paletteLoading: false
    property var paletteColors: []
    property string selectedColor: ""
    property real warningFlash: 0.0

    property string focusArea: wallpaperFocus
    property int paletteColorFocusIndex: -1

    // Discards palette output that belongs to an earlier selection.
    property int paletteGeneration: 0
    property int runningPaletteGeneration: 0
    property var queuedPaletteRequest: null
    property string paletteProcessOutput: ""

    ListModel {
        id: proxyModel
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            if (root.visible)
                root.closePicker();
            else
                root.openPicker();
        }
    }

    MatugenColors {
        id: theme
    }

    function openPicker() {
        visible = true;
        initialFocusSet = false;
        selectedColor = "";
        paletteColors = [];
        focusArea = wallpaperFocus;
        paletteColorFocusIndex = -1;
        loadIndex();

        Qt.callLater(function () {
            view.forceActiveFocus();
            initialFocusSet = true;
        });
    }

    function closePicker() {
        visible = false;
        selectedColor = "";
        paletteColors = [];
        paletteLoading = false;
        paletteGeneration++;
        queuedPaletteRequest = null;
        warningFlash = 0.0;
        focusArea = wallpaperFocus;
        paletteColorFocusIndex = -1;
        Qt.callLater(function () {
            Qt.quit();
        });
    }

    function loadIndex() {
        indexProc.command = ["python3", indexScript];
        indexProc.running = true;
    }

    function parseIndexJson(raw) {
        const text = String(raw || "").trim();
        proxyModel.clear();

        if (text === "")
            return;
        try {
            const data = JSON.parse(text);
            currentWallpaper = String(data.current || "");

            const items = Array.isArray(data.items) ? data.items : [];
            for (let i = 0; i < items.length; ++i) {
                const it = items[i];
                proxyModel.append({
                    key: it.key || "",
                    src: it.src || "",
                    preview: it.preview || "",
                    frame: it.frame || "",
                    type: String(it.type || "image").trim(),
                    name: it.name || ""
                });
            }

            applyFilters(true);
        } catch (e) {
            console.warn("[WallpaperPicker] index parse error:", e);
        }
    }

    function typeMatchesFilter(type, filterName) {
        if (filterName === "All")
            return true;
        if (filterName === "Video")
            return type === "video";
        return true;
    }

    function findFirstMatchingIndex() {
        for (let i = 0; i < proxyModel.count; ++i) {
            if (typeMatchesFilter(proxyModel.get(i).type, currentFilter))
                return i;
        }
        return -1;
    }

    function findNearestMatchingIndex(fromIdx) {
        if (proxyModel.count === 0)
            return -1;
        if (fromIdx < 0)
            return findFirstMatchingIndex();

        let best = -1;
        let bestDist = Number.POSITIVE_INFINITY;
        for (let i = 0; i < proxyModel.count; ++i) {
            if (!typeMatchesFilter(proxyModel.get(i).type, currentFilter))
                continue;
            const d = Math.abs(i - fromIdx);
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    function applyFilters(resetIndex) {
        if (proxyModel.count === 0) {
            view.currentIndex = -1;
            paletteColors = [];
            selectedColor = "";
            return;
        }

        let idx = resetIndex ? findFirstMatchingIndex() : findNearestMatchingIndex(view.currentIndex);
        if (idx >= 0)
            view.currentIndex = idx;
        else
            view.currentIndex = -1;

        requestPaletteForCurrent();
    }

    function stepToNextValidIndex(direction) {
        if (proxyModel.count === 0)
            return;
        let idx = view.currentIndex;
        if (idx < 0)
            idx = findFirstMatchingIndex();

        for (let step = 0; step < proxyModel.count; ++step) {
            idx = (idx + direction + proxyModel.count) % proxyModel.count;
            if (typeMatchesFilter(proxyModel.get(idx).type, currentFilter)) {
                view.currentIndex = idx;
                requestPaletteForCurrent();
                return;
            }
        }
    }

    function requestPaletteForCurrent() {
        paletteGeneration++;
        selectedColor = "";
        paletteColors = [];
        paletteLoading = false;
        paletteColorFocusIndex = -1;
        queuedPaletteRequest = null;

        if (view.currentIndex < 0 || view.currentIndex >= proxyModel.count)
            return;
        const item = proxyModel.get(view.currentIndex);
        if (!item)
            return;
        queuedPaletteRequest = {
            generation: paletteGeneration,
            source: item.src,
            type: item.type,
            frame: item.frame
        };
        paletteLoading = true;
        startQueuedPaletteRequest();
    }

    function startQueuedPaletteRequest() {
        if (paletteProc.running || !queuedPaletteRequest)
            return;
        const request = queuedPaletteRequest;
        queuedPaletteRequest = null;
        runningPaletteGeneration = request.generation;
        paletteProcessOutput = "";
        paletteProc.command = ["bash", paletteScript, request.source, request.type, request.frame];
        paletteProc.running = true;
    }

    function acceptPaletteResult(raw) {
        if (runningPaletteGeneration !== paletteGeneration)
            return;
        const cleaned = String(raw || "").trim();
        paletteLoading = false;

        if (!cleaned) {
            paletteColors = [];
            return;
        }

        try {
            const colors = JSON.parse(cleaned);
            paletteColors = Array.isArray(colors) ? colors : [];
            selectedColor = "";

            if (focusArea === paletteFocus && paletteColorFocusIndex < 0 && paletteColors.length > 0)
                paletteColorFocusIndex = 0;
        } catch (error) {
            console.warn("[WallpaperPicker] Failed to parse palette JSON:", error);
            paletteColors = [];
        }
    }

    function applyWallpaper(src, color) {
        if (!src)
            return;
        if (color && String(color).trim() !== "")
            Quickshell.execDetached(["bash", applyScript, src, color]);
        else
            Quickshell.execDetached(["bash", applyScript, src]);

        closePicker();
    }

    function activatePaletteFocus() {
        focusArea = paletteFocus;

        if (paletteColors.length > 0)
            paletteColorFocusIndex = 0;
        else
            paletteColorFocusIndex = -1;
    }

    function returnToWallpapers() {
        focusArea = wallpaperFocus;
        paletteColorFocusIndex = -1;
        view.forceActiveFocus();
    }

    function movePaletteFocus(direction) {
        if (paletteColors.length <= 0)
            return;
        if (paletteColorFocusIndex < 0)
            paletteColorFocusIndex = 0;
        else
            paletteColorFocusIndex = (paletteColorFocusIndex + direction + paletteColors.length) % paletteColors.length;
    }

    function activatePaletteColor() {
        if (paletteColorFocusIndex < 0 || paletteColorFocusIndex >= paletteColors.length)
            return;
        const chosen = paletteColors[paletteColorFocusIndex];
        selectedColor = chosen;

        if (view.currentIndex >= 0 && view.currentIndex < proxyModel.count) {
            const item = proxyModel.get(view.currentIndex);
            applyWallpaper(item.src, chosen);
        }
    }

    function applyCurrentSelectionOrWarn() {
        if (view.currentIndex < 0 || view.currentIndex >= proxyModel.count)
            return;
        const item = proxyModel.get(view.currentIndex);
        if (!item)
            return;
        if (focusArea !== paletteFocus) {
            activatePaletteFocus();
            return;
        }

        if (!selectedColor) {
            warnAnim.restart();
            return;
        }

        applyWallpaper(item.src, selectedColor);
    }

    Process {
        id: indexProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (typeof text === "function") ? text() : text;
                root.parseIndexJson(raw);
            }
        }
    }

    Process {
        id: paletteProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.paletteProcessOutput = (typeof text === "function") ? text() : text
        }

        onExited: (code, status) => {
            if (root.runningPaletteGeneration === root.paletteGeneration) {
                if (code === 0 && status === 0)
                    root.acceptPaletteResult(root.paletteProcessOutput);
                else {
                    root.paletteLoading = false;
                    root.paletteColors = [];
                }
            }

            Qt.callLater(root.startQueuedPaletteRequest);
        }
    }

    SequentialAnimation {
        id: warnAnim
        NumberAnimation {
            target: root
            property: "warningFlash"
            from: 0.0
            to: 1.0
            duration: root.warningOnDuration
        }
        NumberAnimation {
            target: root
            property: "warningFlash"
            from: 1.0
            to: 0.0
            duration: root.warningOffDuration
        }
        NumberAnimation {
            target: root
            property: "warningFlash"
            from: 0.0
            to: 1.0
            duration: root.warningOnDuration
        }
        NumberAnimation {
            target: root
            property: "warningFlash"
            from: 1.0
            to: 0.0
            duration: root.warningOffDuration
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.focusArea === root.paletteFocus)
                root.returnToWallpapers();
            else
                root.closePicker();
        }
    }

    Shortcut {
        sequence: "Left"
        onActivated: {
            if (root.focusArea === root.paletteFocus)
                root.movePaletteFocus(-1);
            else
                root.stepToNextValidIndex(-1);
        }
    }

    Shortcut {
        sequence: "Right"
        onActivated: {
            if (root.focusArea === root.paletteFocus)
                root.movePaletteFocus(1);
            else
                root.stepToNextValidIndex(1);
        }
    }

    Shortcut {
        sequence: "Return"
        onActivated: {
            if (root.focusArea === root.paletteFocus)
                root.activatePaletteColor();
            else
                root.applyCurrentSelectionOrWarn();
        }
    }

    Shortcut {
        sequence: "Enter"
        onActivated: {
            if (root.focusArea === root.paletteFocus)
                root.activatePaletteColor();
            else
                root.applyCurrentSelectionOrWarn();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePicker()
        }
    }

    ListView {
        id: view

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        height: cardAppearance.cardHeight + cardAppearance.thumbnailOverscan
        spacing: 0
        orientation: ListView.Horizontal
        interactive: false
        clip: false
        focus: root.focusArea === root.wallpaperFocus
        model: proxyModel

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - cardAppearance.expandedCardWidth - cardAppearance.cardSpacing) / 2
        preferredHighlightEnd: (width + cardAppearance.expandedCardWidth + cardAppearance.cardSpacing) / 2
        highlightMoveDuration: root.initialFocusSet ? cardAppearance.cardTransitionDuration : 0

        header: Item {
            width: Math.max(0, (view.width - cardAppearance.expandedCardWidth) / 2)
        }
        footer: Item {
            width: Math.max(0, (view.width - cardAppearance.expandedCardWidth) / 2)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function (wheel) {
                if (root.focusArea !== root.wallpaperFocus) {
                    wheel.accepted = true;
                    return;
                }
                let delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                root.stepToNextValidIndex(delta > 0 ? -1 : 1);
                wheel.accepted = true;
            }
        }

        delegate: WallpaperCard {
            required property int index

            appearance: cardAppearance
            palette: theme
            matchesFilter: root.typeMatchesFilter(type, root.currentFilter)
            isApplied: src === root.currentWallpaper
            onChosen: {
                view.currentIndex = index;
                root.requestPaletteForCurrent();
                root.returnToWallpapers();
            }
        }
    }

    Rectangle {
        id: filterBar

        anchors {
            bottom: view.top
            bottomMargin: 14
            horizontalCenter: parent.horizontalCenter
        }

        z: 20
        height: 58
        width: filterRow.width + 26
        radius: 16
        color: Qt.rgba(theme.mantle.r, theme.mantle.g, theme.mantle.b, 0.94)

        border.color: warningFlash > 0 ? Qt.rgba(1.0, 0.25, 0.25, 0.95) : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.75)
        border.width: warningFlash > 0 ? 2 : 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(1.0, 0.15, 0.15, 0.16 * warningFlash)
        }

        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: 10

            Repeater {
                model: 2

                delegate: Item {
                    id: filterButton

                    required property int index

                    readonly property bool isAll: filterButton.index === 0
                    readonly property string filterName: isAll ? "All" : "Video"
                    readonly property bool activeFilter: root.currentFilter === filterName

                    width: 44
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: filterButton.activeFilter ? theme.surface1 : "transparent"

                        border.color: filterButton.activeFilter ? theme.text : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.5)
                        border.width: filterButton.activeFilter ? 2 : 1

                        scale: filterButton.activeFilter ? 1.08 : (btnArea.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: root.controlTransitionDuration
                                easing.type: Easing.OutQuad
                            }
                        }

                        Canvas {
                            visible: filterButton.isAll
                            width: 14
                            height: 14
                            anchors.centerIn: parent

                            property color iconColor: filterButton.activeFilter ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)
                            onIconColorChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = iconColor;
                                ctx.fillRect(0, 0, 6, 6);
                                ctx.fillRect(8, 0, 6, 6);
                                ctx.fillRect(0, 8, 6, 6);
                                ctx.fillRect(8, 8, 6, 6);
                            }
                        }

                        Canvas {
                            visible: !filterButton.isAll
                            width: 14
                            height: 16
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 2

                            property color iconColor: filterButton.activeFilter ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)
                            onIconColorChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.reset();
                                ctx.fillStyle = iconColor;
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(14, 8);
                                ctx.lineTo(0, 16);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentFilter = filterButton.filterName;
                            root.applyFilters(true);
                            root.returnToWallpapers();
                        }
                    }
                }
            }

            Item {
                width: 8
                height: 1
            }

            Text {
                visible: paletteLoading || paletteColors.length === 0 || selectedColor !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: paletteLoading ? "Loading palette..." : (focusArea === paletteFocus ? "Choose color → Enter to apply" : "Press Enter")
                color: theme.text
                font.pixelSize: 14
                font.bold: true
            }

            Repeater {
                model: paletteColors

                delegate: Item {
                    id: swatch

                    required property int index
                    required property var modelData

                    readonly property bool isFocused: root.focusArea === root.paletteFocus && root.paletteColorFocusIndex === swatch.index
                    readonly property bool isSelected: root.selectedColor === swatch.modelData
                    readonly property bool isAutoPrimary: swatch.index === 0 && root.selectedColor === swatch.modelData

                    width: 34
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: swatch.modelData
                        border.color: swatch.isFocused || swatch.isSelected ? root.swatchHighlight : "#00000000"
                        border.width: swatch.isFocused ? 3 : (swatch.isSelected ? 2 : 0)
                        scale: swatch.isFocused ? 1.10 : (swatch.isSelected ? 1.06 : (swatchArea.containsMouse ? 1.04 : 1.0))

                        Behavior on scale {
                            NumberAnimation {
                                duration: root.swatchTransitionDuration
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    Rectangle {
                        visible: swatch.isAutoPrimary
                        width: 14
                        height: 14
                        radius: 7
                        anchors {
                            right: parent.right
                            top: parent.top
                            margins: -2
                        }
                        color: root.autoBadgeBackground
                        border.color: root.swatchHighlight
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            color: root.swatchHighlight
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: swatchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedColor = swatch.modelData;
                            if (view.currentIndex >= 0 && view.currentIndex < proxyModel.count) {
                                const item = proxyModel.get(view.currentIndex);
                                root.applyWallpaper(item.src, swatch.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
