import QtQuick

// The search HUD: a glass capsule floating in front of the lower part of the
// planet, with the result status underneath. The item is centred on the planet;
// `reach` tells the satellite layout how far from that centre it extends.
Item {
    id: root

    property real globeScale: 1
    property real settled: 0
    property string statusText: ""
    property alias query: input.text

    signal cancelled
    signal submitted
    signal moved(int delta)
    signal movedInDirection(int dx, int dy)

    readonly property real entranceScale: .85
    readonly property real entranceRise: 40

    QtObject {
        id: capsule

        readonly property real width: 236
        readonly property real height: 46
        // Capsule centre below the planet's centre, in planet radii.
        readonly property real offset: .62
        readonly property real padding: 18
        readonly property real iconSize: 16
        readonly property real iconGap: 12
        readonly property real statusGap: 8
        readonly property real statusWidth: 200
    }

    // Farthest corner of the capsule or the status line from the planet's centre.
    readonly property real reach: {
        const top = Theme.globeRadius * capsule.offset - capsule.height / 2;
        const statusBottom = top + capsule.height + capsule.statusGap + status.height;
        return Math.max(Theme.globeRadius,
            Math.hypot(capsule.width / 2, top + capsule.height),
            Math.hypot(capsule.statusWidth / 2, statusBottom));
    }

    function focusInput() {
        input.forceActiveFocus();
    }

    width: Theme.globeRadius * 2
    height: width
    opacity: settled
    scale: globeScale * (entranceScale + (1 - entranceScale) * settled)
    transform: Translate {
        y: (1 - root.settled) * root.entranceRise
    }

    Rectangle {
        id: field

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height / 2 + Theme.globeRadius * capsule.offset - height / 2
        width: capsule.width
        height: capsule.height
        radius: height / 2
        color: Theme.glass
        border.color: Qt.alpha(Theme.atmosphere, input.activeFocus ? .55 : .3)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.motion
            }
        }

        // Magnifier, drawn so it does not depend on an icon font.
        Item {
            id: icon

            x: capsule.padding
            anchors.verticalCenter: parent.verticalCenter
            width: capsule.iconSize
            height: capsule.iconSize

            Rectangle {
                width: parent.width * .72
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Theme.atmosphere
                border.width: 1.6
            }

            Rectangle {
                x: parent.width * .6
                y: parent.height * .68
                width: parent.width * .42
                height: 1.8
                radius: height / 2
                rotation: 45
                transformOrigin: Item.Left
                color: Theme.atmosphere
            }
        }

        TextInput {
            id: input

            objectName: "search"
            anchors.left: icon.right
            anchors.leftMargin: capsule.iconGap
            anchors.right: parent.right
            anchors.rightMargin: capsule.padding
            anchors.verticalCenter: parent.verticalCenter
            focus: true
            color: Theme.text
            selectionColor: Theme.selection
            font.family: Theme.font
            font.pixelSize: Theme.fontSearch
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            clip: true
            maximumLength: 120

            Keys.onEscapePressed: root.cancelled()
            Keys.onReturnPressed: root.submitted()
            Keys.onEnterPressed: root.submitted()
            Keys.onDownPressed: root.movedInDirection(0, 1)
            Keys.onUpPressed: root.movedInDirection(0, -1)
            Keys.onLeftPressed: root.movedInDirection(-1, 0)
            Keys.onRightPressed: root.movedInDirection(1, 0)
            Keys.onTabPressed: root.moved(1)
            Keys.onBacktabPressed: root.moved(-1)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text.length
                text: "Search applications"
                color: Theme.muted
                font: input.font
            }
        }
    }

    Text {
        id: status

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: field.bottom
        anchors.topMargin: capsule.statusGap
        width: capsule.statusWidth
        text: root.statusText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: Theme.fontCaption
    }
}
