import QtQuick
import Quickshell
import Quickshell.Wayland
import "Scatter.js" as Scatter

ShellRoot {
    id: root

    readonly property string variant: Quickshell.env("QS_OBJECT_VARIANT") || "empty"
    property int catalogCount: 0
    property var measuredLayout: null
    property bool released: false

    readonly property var catalog: variant === "layout-only" || variant === "satellites-only" ? entries().filter(entry => !entry.noDisplay).sort((a, b) => a.name.localeCompare(b.name)) : []

    function measureLayout(width, height) {
        const scale = Math.min(1, width / 600, height / 500);
        measuredLayout = Scatter.create(catalog.length, width, height, {
            itemHalfWidth: (Theme.craftWidth + Theme.craftDriftX) / 2 + Theme.craftClearanceX,
            itemHalfHeight: (Theme.craftHeight + Theme.craftDriftY) / 2 + Theme.craftClearanceY,
            centerRadius: Theme.globeRadius * scale + 8
        });
    }

    function entries() {
        return DesktopEntries.applications.values;
    }

    function selectedEntries() {
        const available = entries();
        if (variant === "full" || variant === "release" || variant === "release-gc")
            return available;
        if (variant.startsWith("count-"))
            return available.filter(entry => !entry.noDisplay).slice(0, Number(variant.slice(6)));
        return [];
    }

    PanelWindow {
        visible: false
        screen: Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher-object-check"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Launcher {
            id: launcher

            anchors.fill: parent
            presenting: false
            applications: !root.released && (root.variant === "full" || root.variant.startsWith("count-") || root.variant.startsWith("release")) ? root.selectedEntries() : []
        }

        Item {
            anchors.fill: parent

            Repeater {
                model: root.variant === "satellites-only" ? root.catalog : []

                Satellite {
                    required property int index

                    slot: index
                    entry: root.catalog[index]
                    active: true
                    basePosition: Qt.point(0, 0)
                    width: launcher.width
                    height: launcher.height
                    arrival: 0
                }
            }
        }
    }

    Component.onCompleted: {
        if (variant === "catalog")
            catalogCount = entries().length;
        if (variant === "layout-only")
            Qt.callLater(() => measureLayout(launcher.width, launcher.height));
    }

    Timer {
        interval: 3000
        running: root.variant.startsWith("release")
        onTriggered: {
            root.released = true;
            if (root.variant === "release-gc")
                Qt.callLater(() => gc());
        }
    }
}
