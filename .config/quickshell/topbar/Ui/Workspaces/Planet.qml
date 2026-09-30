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
    property bool expanded: true
    property bool animateEntry: true
    readonly property bool textureReady: surface.status === Image.Ready || surface.status === Image.Error
    readonly property bool originalPlanets: Config.workspaces.planetSet === "original"
    readonly property var appearance: Surface.appearance(workspaceId, originalPlanets)
    readonly property int imageIndex: (workspaceId - 1) % (originalPlanets ? 12 : 10) + 1
    readonly property string imagePath: "Assets/" + (originalPlanets ? "original" : "expanded")
        + "/planet-" + (imageIndex < 10 ? "00" : "0") + imageIndex + ".png"
    signal activated()
    signal concealed()

    width: 44
    height: Theme.barHeight - Theme.pillMarginV * 2

    PlanetSplash {
        id: reveal
        anchors.fill: parent
        expanded: root.expanded
        animateEntry: root.animateEntry
        onClosed: root.concealed()

        PlanetRing {
            anchors.centerIn: parent
            visible: root.appearance.ring !== undefined
            tilt: root.appearance.ring ?? -0.35
        }

        Image {
            id: surface
            anchors.centerIn: parent
            width: 64
            height: 64
            scale: root.appearance.diameter / 64
            smooth: true
            asynchronous: true
            cache: true
            sourceSize: Qt.size(64, 64)
            source: Qt.resolvedUrl(root.imagePath)
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
            opacity: root.textureReady ? 1 : 0
            width: 24
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: root.interactive && reveal.progress > 0.9
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
