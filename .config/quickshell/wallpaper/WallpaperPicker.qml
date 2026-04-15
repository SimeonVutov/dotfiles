import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors { top: true; bottom: true; left: true; right: true }
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

    readonly property int itemWidth: 400
    readonly property int itemHeight: 420
    readonly property int cardSpacing: 10
    readonly property int borderWidth: 3
    readonly property real skewFactor: -0.35

    property string currentWallpaper: ""
    property string currentFilter: "All"
    property bool initialFocusSet: false
    property bool paletteLoading: false
    property var paletteColors: []
    property string selectedColor: ""
    property real warningFlash: 0.0

    property string focusZone: "wallpapers" // wallpapers | palette
    property int paletteColorFocusIndex: -1 // only indexes inside paletteColors

    ListModel { id: proxyModel }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            if (root.visible) root.closePicker()
            else root.openPicker()
        }
    }

    MatugenColors { id: theme }

    function openPicker() {
        visible = true
        initialFocusSet = false
        selectedColor = ""
        paletteColors = []
        focusZone = "wallpapers"
        paletteColorFocusIndex = -1
        loadIndex()

        Qt.callLater(function() {
            view.forceActiveFocus()
            initialFocusSet = true
        })
    }

    function closePicker() {
        visible = false
        selectedColor = ""
        paletteColors = []
        paletteLoading = false
        warningFlash = 0.0
        focusZone = "wallpapers"
        paletteColorFocusIndex = -1
        Qt.callLater(function() {
            Qt.quit()
        })
    }

    function loadIndex() {
        indexProc.command = ["python3", indexScript]
        indexProc.running = true
    }

    function parseIndexJson(raw) {
        const text = String(raw || "").trim()
        proxyModel.clear()

        if (text === "")
            return

        try {
            const data = JSON.parse(text)
            currentWallpaper = String(data.current || "")

            const items = Array.isArray(data.items) ? data.items : []
            for (let i = 0; i < items.length; ++i) {
                const it = items[i]
                proxyModel.append({
                    key: it.key || "",
                    src: it.src || "",
                    preview: it.preview || "",
                    frame: it.frame || "",
                    type: String(it.type || "image").trim(),
                    name: it.name || ""
                })
            }

            applyFilters(true)
        } catch (e) {
            console.warn("[WallpaperPicker] index parse error:", e)
        }
    }

    function checkItemMatchesFilter(item, filterName) {
        if (!item) return false
        if (filterName === "All") return true
        if (filterName === "Video") return item.type === "video"
        return true
    }

    function findFirstMatchingIndex() {
        for (let i = 0; i < proxyModel.count; ++i) {
            if (checkItemMatchesFilter(proxyModel.get(i), currentFilter))
                return i
        }
        return -1
    }

    function findNearestMatchingIndex(fromIdx) {
        if (proxyModel.count === 0)
            return -1
        if (fromIdx < 0)
            return findFirstMatchingIndex()

        let best = -1
        let bestDist = 999999
        for (let i = 0; i < proxyModel.count; ++i) {
            if (!checkItemMatchesFilter(proxyModel.get(i), currentFilter))
                continue
            const d = Math.abs(i - fromIdx)
            if (d < bestDist) {
                bestDist = d
                best = i
            }
        }
        return best
    }

    function applyFilters(resetIndex) {
        if (proxyModel.count === 0) {
            view.currentIndex = -1
            paletteColors = []
            selectedColor = ""
            return
        }

        let idx = resetIndex ? findFirstMatchingIndex() : findNearestMatchingIndex(view.currentIndex)
        if (idx >= 0)
            view.currentIndex = idx
        else
            view.currentIndex = -1

        requestPaletteForCurrent()
    }

    function stepToNextValidIndex(direction) {
        if (proxyModel.count === 0)
            return

        let idx = view.currentIndex
        if (idx < 0)
            idx = findFirstMatchingIndex()

        for (let step = 0; step < proxyModel.count; ++step) {
            idx = (idx + direction + proxyModel.count) % proxyModel.count
            if (checkItemMatchesFilter(proxyModel.get(idx), currentFilter)) {
                view.currentIndex = idx
                requestPaletteForCurrent()
                return
            }
        }
    }

    function requestPaletteForCurrent() {
        selectedColor = ""
        paletteColors = []
        paletteLoading = false
        paletteColorFocusIndex = -1

        if (view.currentIndex < 0 || view.currentIndex >= proxyModel.count)
            return

        const item = proxyModel.get(view.currentIndex)
        if (!item)
            return

        paletteProc.command = ["bash", paletteScript, item.src, item.type, item.frame]
        paletteLoading = true
        paletteProc.running = true
    }

    function applyWallpaper(src, color) {
        if (!src)
            return

        if (color && String(color).trim() !== "")
            Quickshell.execDetached(["bash", applyScript, src, color])
        else
            Quickshell.execDetached(["bash", applyScript, src])

        closePicker()
    }

    function activatePaletteFocus() {
        focusZone = "palette"

        if (paletteColors.length > 0)
        paletteColorFocusIndex = 0
        else
        paletteColorFocusIndex = -1
    }

    function returnToWallpapers() {
        focusZone = "wallpapers"
        paletteColorFocusIndex = -1
        view.forceActiveFocus()
    }

    function movePaletteFocus(direction) {
        if (paletteColors.length <= 0)
            return

        if (paletteColorFocusIndex < 0)
            paletteColorFocusIndex = 0
        else
            paletteColorFocusIndex = (paletteColorFocusIndex + direction + paletteColors.length) % paletteColors.length
    }

    function activatePaletteColor() {
        if (paletteColorFocusIndex < 0 || paletteColorFocusIndex >= paletteColors.length)
            return

        const chosen = paletteColors[paletteColorFocusIndex]
        selectedColor = chosen

        if (view.currentIndex >= 0 && view.currentIndex < proxyModel.count) {
            const item = proxyModel.get(view.currentIndex)
            applyWallpaper(item.src, chosen)
        }
    }
    
    function applyCurrentSelectionOrWarn() {
        if (view.currentIndex < 0 || view.currentIndex >= proxyModel.count)
        return

        const item = proxyModel.get(view.currentIndex)
        if (!item)
        return

        // FIRST ENTER → move to palette
        if (focusZone !== "palette") {
            activatePaletteFocus()
            return
        }

        // SECOND ENTER → apply
        if (!selectedColor) {
            warnAnim.restart()
            return
        }

        applyWallpaper(item.src, selectedColor)
    }

    Process {
        id: indexProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (typeof text === "function") ? text() : text
                root.parseIndexJson(raw)
            }
        }
    }

    Process {
        id: paletteProc
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (typeof text === "function") ? text() : text
                const cleaned = String(raw || "").trim()
                root.paletteLoading = false

                if (cleaned === "") {
                    root.paletteColors = []
                    return
                }

                try {
                    const arr = JSON.parse(cleaned)
                    root.paletteColors = Array.isArray(arr) ? arr : []
                    
                    root.selectedColor = ""

                    if (root.focusZone === "palette" && root.paletteColorFocusIndex < 0 && root.paletteColors.length > 0) {
                        const idx = root.paletteColors.indexOf(root.selectedColor)
                        root.paletteColorFocusIndex = idx >= 0 ? idx : 0
                    }
                } catch (e) {
                    console.warn("[WallpaperPicker] Failed to parse palette JSON:", e)
                    root.paletteColors = []
                }
            }
        }
    }

    SequentialAnimation {
        id: warnAnim
        NumberAnimation { target: root; property: "warningFlash"; from: 0.0; to: 1.0; duration: 120 }
        NumberAnimation { target: root; property: "warningFlash"; from: 1.0; to: 0.0; duration: 180 }
        NumberAnimation { target: root; property: "warningFlash"; from: 0.0; to: 1.0; duration: 120 }
        NumberAnimation { target: root; property: "warningFlash"; from: 1.0; to: 0.0; duration: 180 }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.focusZone === "palette")
                root.returnToWallpapers()
            else
                root.closePicker()
        }
    }

    Shortcut {
        sequence: "Left"
        onActivated: {
            if (root.focusZone === "palette")
                root.movePaletteFocus(-1)
            else
                root.stepToNextValidIndex(-1)
        }
    }

    Shortcut {
        sequence: "Right"
        onActivated: {
            if (root.focusZone === "palette")
                root.movePaletteFocus(1)
            else
                root.stepToNextValidIndex(1)
        }
    }

    Shortcut {
        sequence: "Return"
        onActivated: {
            if (root.focusZone === "palette")
                root.activatePaletteColor()
            else
                root.applyCurrentSelectionOrWarn()
        }
    }

    Shortcut {
        sequence: "Enter"
        onActivated: {
            if (root.focusZone === "palette")
                root.activatePaletteColor()
            else
                root.applyCurrentSelectionOrWarn()
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

        height: root.itemHeight + 80
        spacing: 0
        orientation: ListView.Horizontal
        interactive: false
        clip: false
        focus: root.focusZone === "wallpapers"
        model: proxyModel

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((root.itemWidth * 1.5 + root.cardSpacing) / 2)
        preferredHighlightEnd: (width / 2) + ((root.itemWidth * 1.5 + root.cardSpacing) / 2)
        highlightMoveDuration: root.initialFocusSet ? 260 : 0

        header: Item { width: Math.max(0, (view.width / 2) - (root.itemWidth * 0.75)) }
        footer: Item { width: Math.max(0, (view.width / 2) - (root.itemWidth * 0.75)) }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
                if (root.focusZone !== "wallpapers") {
                    wheel.accepted = true
                    return
                }
                let delta = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                    ? wheel.angleDelta.x
                    : wheel.angleDelta.y
                root.stepToNextValidIndex(delta > 0 ? -1 : 1)
                wheel.accepted = true
            }
        }

        delegate: Item {
            id: card

            readonly property bool matchesFilter: root.checkItemMatchesFilter(model, root.currentFilter)
            readonly property bool currentItem: ListView.isCurrentItem
            readonly property bool isVideo: type === "video"
            readonly property bool isApplied: src === root.currentWallpaper
            readonly property real targetW: currentItem ? (root.itemWidth * 1.5) : (root.itemWidth * 0.5)
            readonly property real targetH: currentItem ? (root.itemHeight + 30) : root.itemHeight

            width: matchesFilter ? (targetW + root.cardSpacing) : 0
            height: matchesFilter ? targetH : 0
            visible: width > 1 && height > 1
            opacity: matchesFilter ? (currentItem ? 1.0 : 0.55) : 0.0
            z: currentItem ? 10 : 1

            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: 0

            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutQuad } }

            Item {
                id: inner
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((root.itemHeight - height) / 2) * root.skewFactor
                width: parent.width > 0 ? parent.width * (card.targetW / (card.targetW + root.cardSpacing)) : 0
                height: parent.height

                transform: Matrix4x4 {
                    property real s: root.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0,
                                         0, 0, 0, 1)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: card.matchesFilter
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.currentIndex = index
                        root.requestPaletteForCurrent()
                        root.returnToWallpapers()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Qt.rgba(0, 0, 0, card.currentItem ? 0.28 : 0.18)
                    scale: 1.02
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: root.borderWidth
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: "#0d0d0d"
                    }

                    Image {
                        id: thumb
                        anchors.centerIn: parent
                        width: (root.itemWidth * 1.5) + ((root.itemHeight + 30) * Math.abs(root.skewFactor)) + 80
                        height: root.itemHeight + 30
                        fillMode: Image.PreserveAspectCrop
                        source: preview ? ("file://" + preview) : ""
                        sourceSize.width: Math.max(900, Math.round(width * 1.35))
                        sourceSize.height: Math.max(540, Math.round(height * 1.35))
                        asynchronous: true
                        smooth: true
                        mipmap: true

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: thumb.status !== Image.Ready
                            color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.65)
                        }
                    }

                    Rectangle {
                        visible: card.isVideo
                        anchors { top: parent.top; right: parent.right; margins: 10 }
                        width: 34
                        height: 34
                        radius: 8
                        color: "#99000000"

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        Canvas {
                            anchors.fill: parent
                            anchors.margins: 9
                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = "#EEFFFFFF"
                                ctx.beginPath()
                                ctx.moveTo(3, 0)
                                ctx.lineTo(14, 7)
                                ctx.lineTo(3, 14)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }

                    Rectangle {
                        visible: card.isApplied
                        anchors { top: parent.top; left: parent.left; margins: 10 }
                        width: 88
                        height: 28
                        radius: 8
                        color: Qt.rgba(theme.green.r, theme.green.g, theme.green.b, 0.92)

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Current"
                            color: "#10131a"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    Rectangle {
                        visible: card.currentItem
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 38
                        color: "#cc000000"

                        transform: Matrix4x4 {
                            property real s: -root.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0,
                                                 0, 1, 0, 0,
                                                 0, 0, 1, 0,
                                                 0, 0, 0, 1)
                        }

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 22
                            text: name
                            color: theme.text
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
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

        border.color: warningFlash > 0
            ? Qt.rgba(1.0, 0.25, 0.25, 0.95)
            : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.75)
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
                    readonly property bool isAll: index === 0
                    readonly property string filterName: isAll ? "All" : "Video"
                    readonly property bool activeFilter: root.currentFilter === filterName

                    width: 44
                    height: 38

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: activeFilter ? theme.surface1 : "transparent"

                        border.color: activeFilter
                            ? theme.text
                            : Qt.rgba(theme.surface2.r, theme.surface2.g, theme.surface2.b, 0.5)
                        border.width: activeFilter ? 2 : 1

                        scale: activeFilter ? 1.08 : (btnArea.containsMouse ? 1.05 : 1.0)
                        Behavior on scale {
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }

                        Canvas {
                            visible: isAll
                            width: 14
                            height: 14
                            anchors.centerIn: parent

                            property color iconColor: activeFilter ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)
                            onIconColorChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = iconColor
                                ctx.fillRect(0, 0, 6, 6)
                                ctx.fillRect(8, 0, 6, 6)
                                ctx.fillRect(0, 8, 6, 6)
                                ctx.fillRect(8, 8, 6, 6)
                            }
                        }

                        Canvas {
                            visible: !isAll
                            width: 14
                            height: 16
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 2

                            property color iconColor: activeFilter ? theme.text : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.68)
                            onIconColorChanged: requestPaint()

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = iconColor
                                ctx.beginPath()
                                ctx.moveTo(0, 0)
                                ctx.lineTo(14, 8)
                                ctx.lineTo(0, 16)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentFilter = filterName
                            root.applyFilters(true)
                            root.returnToWallpapers()
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
                text: paletteLoading
                    ? "Loading palette..."
                    : (focusZone === "palette" ? "Choose color → Enter to apply" : "Press Enter")
                color: theme.text
                font.pixelSize: 14
                font.bold: true
            }

            Repeater {
                model: paletteColors

                delegate: Item {
                    readonly property bool isFocused: root.focusZone === "palette" && root.paletteColorFocusIndex === index
                    readonly property bool isSelected: root.selectedColor === modelData
                    readonly property bool isAutoPrimary: index === 0 && root.selectedColor === modelData

                    width: 34
                    height: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: modelData
                        border.color: isFocused || isSelected ? "#ffffff" : "#00000000"
                        border.width: isFocused ? 3 : (isSelected ? 2 : 0)
                        scale: isFocused ? 1.10 : (isSelected ? 1.06 : (swatchArea.containsMouse ? 1.04 : 1.0))

                        Behavior on scale {
                            NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
                        }
                    }

                    Rectangle {
                        visible: isAutoPrimary
                        width: 14
                        height: 14
                        radius: 7
                        anchors {
                            right: parent.right
                            top: parent.top
                            margins: -2
                        }
                        color: "#111111"
                        border.color: "#ffffff"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            color: "#ffffff"
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
                            root.selectedColor = modelData
                            if (view.currentIndex >= 0 && view.currentIndex < proxyModel.count) {
                                const item = proxyModel.get(view.currentIndex)
                                root.applyWallpaper(item.src, modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
