pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "WallpaperFilter.js" as Filter

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

    readonly property int warningOnDuration: 120
    readonly property int warningOffDuration: 180

    readonly property string wallpaperFocus: "wallpapers"
    readonly property string paletteFocus: "palette"

    property string currentFilter: "All"
    property bool initialFocusSet: false
    property string selectedColor: ""
    property real warningFlash: 0.0

    property string focusArea: wallpaperFocus
    property int paletteColorFocusIndex: -1

    CardAppearance {
        id: cardAppearance
    }

    MatugenColors {
        id: matugen
    }

    WallpaperLibrary {
        id: library
        script: root.indexScript
        onLoaded: root.applyFilters(true)
    }

    PaletteLoader {
        id: paletteLoader
        script: root.paletteScript
        onReady: {
            root.selectedColor = "";

            if (root.focusArea === root.paletteFocus && root.paletteColorFocusIndex < 0 && paletteLoader.colors.length > 0)
                root.paletteColorFocusIndex = 0;
        }
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

    function openPicker() {
        visible = true;
        initialFocusSet = false;
        selectedColor = "";
        paletteLoader.colors = [];
        focusArea = wallpaperFocus;
        paletteColorFocusIndex = -1;
        library.load();

        Qt.callLater(function () {
            view.forceActiveFocus();
            initialFocusSet = true;
        });
    }

    function closePicker() {
        visible = false;
        selectedColor = "";
        paletteLoader.reset();
        warningFlash = 0.0;
        focusArea = wallpaperFocus;
        paletteColorFocusIndex = -1;
        Qt.callLater(function () {
            Qt.quit();
        });
    }

    // The wallpaper in the middle of the list, or null when there is none.
    function currentWallpaperItem() {
        if (view.currentIndex < 0 || view.currentIndex >= library.model.count)
            return null;
        return library.model.get(view.currentIndex);
    }

    function selectFilter(name) {
        currentFilter = name;
        applyFilters(true);
        returnToWallpapers();
    }

    function applyFilters(resetIndex) {
        if (library.model.count === 0) {
            view.currentIndex = -1;
            paletteLoader.colors = [];
            selectedColor = "";
            return;
        }

        view.currentIndex = resetIndex
            ? Filter.firstMatchingIndex(library.model, currentFilter)
            : Filter.nearestMatchingIndex(library.model, currentFilter, view.currentIndex);

        requestPaletteForCurrent();
    }

    function stepToNextValidIndex(direction) {
        const next = Filter.nextMatchingIndex(library.model, currentFilter, view.currentIndex, direction);
        if (next < 0)
            return;

        view.currentIndex = next;
        requestPaletteForCurrent();
    }

    function requestPaletteForCurrent() {
        selectedColor = "";
        paletteColorFocusIndex = -1;

        const item = currentWallpaperItem();
        if (item)
            paletteLoader.request(item.src, item.type, item.frame);
        else
            paletteLoader.reset();
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

        if (paletteLoader.colors.length > 0)
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
        if (paletteLoader.colors.length <= 0)
            return;
        if (paletteColorFocusIndex < 0)
            paletteColorFocusIndex = 0;
        else
            paletteColorFocusIndex = (paletteColorFocusIndex + direction + paletteLoader.colors.length) % paletteLoader.colors.length;
    }

    // Applies the current wallpaper with the chosen palette colour.
    function chooseColor(color) {
        selectedColor = color;

        const item = currentWallpaperItem();
        if (item)
            applyWallpaper(item.src, color);
    }

    function activatePaletteColor() {
        if (paletteColorFocusIndex < 0 || paletteColorFocusIndex >= paletteLoader.colors.length)
            return;
        chooseColor(paletteLoader.colors[paletteColorFocusIndex]);
    }

    function applyCurrentSelectionOrWarn() {
        const item = currentWallpaperItem();
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

    // The keys act on the palette while it has the focus, otherwise on the wallpapers.
    function escapePressed() {
        if (focusArea === paletteFocus)
            returnToWallpapers();
        else
            closePicker();
    }

    function arrowPressed(direction) {
        if (focusArea === paletteFocus)
            movePaletteFocus(direction);
        else
            stepToNextValidIndex(direction);
    }

    function enterPressed() {
        if (focusArea === paletteFocus)
            activatePaletteColor();
        else
            applyCurrentSelectionOrWarn();
    }

    // Flashes the filter bar twice.
    SequentialAnimation {
        id: warnAnim
        loops: 2

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
        onActivated: root.escapePressed()
    }

    Shortcut {
        sequence: "Left"
        onActivated: root.arrowPressed(-1)
    }

    Shortcut {
        sequence: "Right"
        onActivated: root.arrowPressed(1)
    }

    Shortcut {
        sequence: "Return"
        onActivated: root.enterPressed()
    }

    Shortcut {
        sequence: "Enter"
        onActivated: root.enterPressed()
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
        model: library.model

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
            palette: matugen
            matchesFilter: Filter.matches(type, root.currentFilter)
            isApplied: src === library.current
            onChosen: {
                view.currentIndex = index;
                root.requestPaletteForCurrent();
                root.returnToWallpapers();
            }
        }
    }

    FilterBar {
        anchors {
            bottom: view.top
            bottomMargin: 14
            horizontalCenter: parent.horizontalCenter
        }

        theme: matugen
        filter: root.currentFilter
        loading: paletteLoader.loading
        colors: paletteLoader.colors
        selectedColor: root.selectedColor
        paletteFocused: root.focusArea === root.paletteFocus
        focusedIndex: root.paletteColorFocusIndex
        warningFlash: root.warningFlash
        onFilterChosen: name => root.selectFilter(name)
        onColorChosen: color => root.chooseColor(color)
    }
}
