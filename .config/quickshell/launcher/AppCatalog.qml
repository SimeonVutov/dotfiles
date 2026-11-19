import QtQuick
import Quickshell
import "Search.js" as Search

// The applications the launcher shows, and those matching the search.
Scope {
    id: root

    property var applications: DesktopEntries.applications.values
    required property string query
    property var settledApplications: []
    readonly property int fallbackDelay: 250

    readonly property var catalog: settledApplications.filter(a => !a.noDisplay).slice().sort((a, b) => a.name.localeCompare(b.name))
    readonly property var results: Search.rank(catalog, query)
    // Tested per satellite on every pointer move, so keep membership O(1).
    readonly property var resultSet: new Set(results)

    onApplicationsChanged: refresh.restart()

    Component.onCompleted: {
        // This process starts for each opening, so the applications are often
        // loaded already: start from them rather than waiting out the delay.
        if (applications.length)
            settledApplications = applications.slice();
        else
            refresh.restart();
    }

    // DesktopEntries signals once after its per-entry model updates.
    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            refresh.stop();
            root.settledApplications = root.applications.slice();
        }
    }

    // Also handles application lists supplied by previews and tests.
    Timer {
        id: refresh

        interval: root.fallbackDelay
        onTriggered: root.settledApplications = root.applications.slice()
    }
}
