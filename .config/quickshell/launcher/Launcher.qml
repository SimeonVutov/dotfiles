import QtQuick
import Quickshell

FocusScope {
    id: root
    signal dismissed
    signal launchRequested(var entry)
    property var applications: DesktopEntries.applications.values
    property int page: 0
    property int selectedIndex: 0
    property bool ready: false
    property string launchError: ""
    property alias query: search.text
    focus: true
    function focusSearch() {
        search.forceActiveFocus();
    }
    onVisibleChanged: if (visible)
        Qt.callLater(focusSearch)
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.dismissed()
    }
    readonly property int pageSize: 12
    readonly property var results: {
        const query = search.text.trim().toLowerCase();
        const tokens = query.split(/\s+/).filter(t => t.length);
        return applications.filter(a => !a.noDisplay && tokens.every(t => (a.name + " " + a.genericName + " " + a.comment).toLowerCase().includes(t))).sort((a, b) => {
            const rank = app => app.name.toLowerCase() === query ? 0 : app.name.toLowerCase().startsWith(query) ? 1 : 2;
            return rank(a) - rank(b) || a.name.localeCompare(b.name);
        });
    }
    readonly property int pages: Math.max(1, Math.ceil(results.length / pageSize))
    readonly property var pageEntries: results.slice(page * pageSize, (page + 1) * pageSize)

    // Preserve surviving slots; update pending replacements during rapid typing.
    function reconcile() {
        if (!ready)
            return;
        const pending = pageEntries.slice();
        const assigned = new Array(pageSize).fill(null);
        for (let i = 0; i < pageSize; i++) {
            const sat = satellites.itemAt(i);
            const app = pending.includes(sat.entry) ? sat.entry : sat.pendingEntry;
            const found = pending.indexOf(app);
            if (found >= 0) {
                assigned[i] = app;
                pending.splice(found, 1);
            }
        }
        for (let i = 0; i < pageSize; i++) {
            if (!assigned[i] && pending.length)
                assigned[i] = pending.shift();
            satellites.itemAt(i).target(assigned[i]);
        }
    }
    function moveSelection(delta) {
        if (!results.length)
            return;
        const absolute = (page * pageSize + selectedIndex + delta + results.length) % results.length;
        page = Math.floor(absolute / pageSize);
        selectedIndex = absolute % pageSize;
    }
    function changePage(delta) {
        page = (page + delta + pages) % pages;
        selectedIndex = 0;
    }
    onResultsChanged: {
        page = 0;
        selectedIndex = 0;
        Qt.callLater(reconcile);
    }
    onPageChanged: Qt.callLater(reconcile)
    Component.onCompleted: {
        ready = true;
        reconcile();
        Qt.callLater(focusSearch);
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.abyss
        opacity: .94
    }
    MouseArea {
        anchors.fill: parent
        onClicked: search.forceActiveFocus()
    }
    Item {
        id: universe
        width: 1700
        height: 1050
        anchors.centerIn: parent
        scale: Math.min(1, (root.width - 24) / width, (root.height - 24) / height)
        opacity: 0
        Component.onCompleted: entrance.start()
        NumberAnimation {
            id: entrance
            target: universe
            property: "opacity"
            to: 1
            duration: 260
        }
        Repeater {
            model: 90
            Rectangle {
                required property int index
                x: (index * 173 + 41) % universe.width
                y: (index * 97 + 11) % universe.height
                width: index % 5 === 0 ? 2 : 1
                height: width
                radius: 1
                color: Theme.muted
                opacity: .15 + (index % 4) * .09
            }
        }
        OrbitRings {
            anchors.fill: parent
            radii: [[420, 285], [700, 418]]
        }
        Planet {
            anchors.centerIn: parent
            width: 310
            height: 310
        }
        Repeater {
            id: satellites
            model: root.pageSize
            Satellite {
                required property int index
                slot: index
                width: universe.width
                height: universe.height
                tracking: search.text.length > 0
                selected: entry !== null && entry === root.pageEntries[root.selectedIndex]
                onChosen: app => root.launchRequested(app)
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 244
            height: 100
            radius: 14
            color: Theme.background
            border.color: Theme.border
            Text {
                anchors.top: parent.top
                anchors.topMargin: 13
                anchors.horizontalCenter: parent.horizontalCenter
                text: "APPLICATIONS"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            TextInput {
                id: search
                objectName: "search"
                x: 16
                y: 37
                width: parent.width - 32
                height: 28
                color: Theme.text
                selectionColor: "#555555"
                font.family: Theme.font
                font.pixelSize: 19
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                selectByMouse: true
                focus: true
                maximumLength: 120
                Text {
                    anchors.centerIn: parent
                    text: "Search apps"
                    visible: !search.text.length
                    color: Theme.muted
                    font: search.font
                }
                Keys.onEscapePressed: root.dismissed()
                Keys.onReturnPressed: if (root.pageEntries[root.selectedIndex])
                    root.launchRequested(root.pageEntries[root.selectedIndex])
                Keys.onEnterPressed: if (root.pageEntries[root.selectedIndex])
                    root.launchRequested(root.pageEntries[root.selectedIndex])
                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onTabPressed: root.moveSelection(1)
                Keys.onBacktabPressed: root.moveSelection(-1)
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
                        root.changePage(event.key === Qt.Key_PageDown ? 1 : -1);
                        event.accepted = true;
                    }
                }
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.launchError || (root.results.length ? root.results.length + " applications" : "No matching applications")
                font.family: Theme.font
                font.pixelSize: 10
                color: Theme.muted
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 35
            y: 1006
            spacing: 18
            Repeater {
                model: ["‹", "›"]
                Rectangle {
                    required property int index
                    required property string modelData
                    width: 34
                    height: 28
                    radius: 14
                    color: pageMouse.containsMouse ? Theme.border : Theme.surface
                    visible: root.pages > 1
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: Theme.text
                        font.pixelSize: 22
                    }
                    MouseArea {
                        id: pageMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.changePage(parent.index === 0 ? -1 : 1)
                    }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 35
            y: 984
            text: root.pages > 1 ? "Constellation " + (root.page + 1) + " / " + root.pages : ""
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
    Rectangle {
        objectName: "closeButton"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        width: 34
        height: 34
        radius: 17
        color: "transparent"
        border.color: closeMouse.containsMouse ? Theme.text : Theme.border
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motion
            }
        }
        Text {
            anchors.centerIn: parent
            text: "×"
            font.pixelSize: 19
            color: closeMouse.containsMouse ? Theme.text : Theme.muted
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dismissed()
        }
    }
}
