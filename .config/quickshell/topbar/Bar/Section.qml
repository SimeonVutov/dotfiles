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
    property real availableWidth: Infinity
    property int layoutRevision: 0

    spacing: Theme.pillSpacing

    readonly property var preferredWidths: {
        const revision = layoutRevision;
        return moduleIds.map((moduleId, index) => moduleRepeater.itemAt(index)?.preferredModuleWidth || 0);
    }
    readonly property var compressionStates: {
        const widths = preferredWidths.slice();
        const states = {};
        const totalWidth = () => widths.reduce((sum, value) => sum + value, 0) + spacing * Math.max(0, widths.filter(value => value > 0).length - 1);
        for (const step of Config.compressionSteps) {
            if (totalWidth() <= availableWidth)
                break;
            const index = moduleIds.indexOf(step.module);
            if (index < 0)
                continue;
            const item = moduleRepeater.itemAt(index)?.item;
            if (!item)
                continue;
            const current = states[step.module] || { hide: [], view: "", hidden: false };
            const next = {
                hide: step.remove ? current.hide.concat([step.remove]) : current.hide,
                view: step.view || current.view,
                hidden: step.hidden === true || current.hidden
            };
            const proposed = item.widthForCompression(next);
            if (!Number.isFinite(proposed) || proposed >= widths[index] - 0.5)
                continue;
            states[step.module] = next;
            widths[index] = Math.max(0, proposed);
        }
        return states;
    }
    Repeater {
        id: moduleRepeater
        model: root.moduleIds

        Loader {
            id: moduleLoader

            required property var modelData
            property real preferredModuleWidth: item ? item.preferredWidth : implicitWidth

            anchors.verticalCenter: parent.verticalCenter
            width: root.compressionStates[modelData]?.hidden ? 0 : implicitWidth
            visible: width > 0
            opacity: root.compressionStates[modelData]?.hidden ? 0 : 1
            onLoaded: root.layoutRevision++

            Behavior on width {
                enabled: moduleLoader.modelData === "power"
                NumberAnimation {
                    duration: Theme.durationNormal
                    easing.type: Theme.easingEmphasized
                }
            }

            Behavior on opacity {
                enabled: moduleLoader.modelData === "power"
                NumberAnimation {
                    duration: Theme.durationNormal
                    easing.type: Theme.easingEmphasized
                }
            }

            Component.onCompleted: setSource(Config.moduleUrlFor(modelData), {
                "screen": Qt.binding(() => root.screen),
                "moduleViewId": modelData,
                "autoHiddenItems": Qt.binding(() => root.compressionStates[moduleLoader.modelData]?.hide || []),
                "autoView": Qt.binding(() => root.compressionStates[moduleLoader.modelData]?.view || "")
            })
        }
    }
}
