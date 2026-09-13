import QtQuick
import qs.Common

// Register namespaces needed by URL-loaded modules.
import qs.Ui
import qs.Ui.Audio
import qs.Ui.Media
import qs.Ui.Connectivity
import qs.Services
import qs.Popups
import qs.Modules

// Turns configured module ids into live modules.
Row {
    id: root

    property var moduleIds: []
    property var screen: null

    spacing: Theme.pillSpacing

    Repeater {
        model: root.moduleIds

        Loader {
            id: moduleLoader

            required property var modelData

            anchors.verticalCenter: parent.verticalCenter

            Component.onCompleted: setSource(Config.moduleUrlFor(modelData), {
                "screen": Qt.binding(() => root.screen)
            })
        }
    }
}
