import QtQuick
import qs.Common
import qs.Ui
import "PlanetSurface.js" as Surface

Item {
    id: root

    required property int workspaceId
    required property string label
    property bool selected: false
    property bool interactive: true
    property real presence: 1
    property bool surfaceReady: false
    readonly property bool originalPlanets: Config.workspaces.planetSet === "original"
    readonly property var appearance: Surface.appearance(workspaceId, originalPlanets)
    signal activated()

    width: 44
    height: Theme.barHeight - Theme.pillMarginV * 2

    function refreshSurface() {
        if (surface.available)
            surface.requestPaint();
    }

    onWorkspaceIdChanged: {
        surfaceReady = false;
        refreshSurface();
    }
    onOriginalPlanetsChanged: {
        surfaceReady = false;
        refreshSurface();
    }
    onPresenceChanged: if (presence > 0 && !surfaceReady) refreshSurface()

    Item {
        anchors.fill: parent
        opacity: root.presence

        PlanetRing {
            anchors.centerIn: parent
            visible: root.appearance.ring !== undefined
            tilt: root.appearance.ring ?? -0.35
        }

        Canvas {
            id: surface
            anchors.centerIn: parent
            width: 64
            height: 64
            scale: root.appearance.diameter / 64
            smooth: true
            onAvailableChanged: {
                root.surfaceReady = false;
                if (available)
                    requestPaint();
            }
            onPaint: {
                Surface.paint(getContext("2d"), 64, root.workspaceId, root.originalPlanets);
                root.surfaceReady = true;
            }
        }

        PlanetRing {
            anchors.centerIn: parent
            visible: root.appearance.ring !== undefined
            tilt: root.appearance.ring ?? -0.35
            foreground: true
        }

        BarText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 2
            text: root.label
            font.pixelSize: 10
            font.bold: true
            color: root.selected || hit.containsMouse ? "#FFFFFF" : "#C8C8C8"
            style: Text.Outline
            styleColor: "#99000000"
            opacity: root.surfaceReady ? 1 : 0
            width: 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: root.interactive && root.presence > 0.2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
