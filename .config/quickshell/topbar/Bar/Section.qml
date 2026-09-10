import QtQuick
import qs.Common

// Modules are loaded by URL rather than as declared types, and the QML engine
// only resolves a `qs.*` import inside such a file if something already in the
// statically imported graph registered it. Importing the namespaces the
// modules use here is what makes them available to every module.
import qs.Ui
import qs.Services
import qs.Popups
import qs.Modules

// Turns a list of module ids into live modules. This is the whole of the bar's
// layout engine: reorder the array in Config.qml and the row reorders itself.
Row {
    id: root

    property var moduleIds: []
    property var screen: null
    property string section: ""

    spacing: Theme.pillSpacing

    Repeater {
        model: root.moduleIds

        Loader {
            id: moduleLoader

            required property var modelData

            anchors.verticalCenter: parent.verticalCenter

            // setSource is what lets the bar hand a module its context without
            // every module having to reach back up through its parents.
            Component.onCompleted: setSource(Registry.urlFor(modelData), {
                "screen": Qt.binding(() => root.screen),
                "moduleId": modelData,
                "section": root.section
            })
        }
    }
}
