import QtQuick

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

    readonly property real entranceScale: .65
    readonly property real entranceRise: 110

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

    // Rows run down the dial's axis rather than in a Column, so their offsets
    // stay independent of font metrics and the block keeps its optical centre.
    QtObject {
        id: dial

        readonly property real diameter: 214
        readonly property real sidePadding: 18
        readonly property real rulerWidth: 98
        readonly property real rulerHeight: 1
        readonly property real statusWidth: 180

        readonly property real headingTop: 45
        readonly property real headingGap: 38
        readonly property real queryHeight: 32
        readonly property real queryGap: 16
        readonly property real rulerGap: 18

        readonly property real queryTop: headingTop + headingGap
        readonly property real rulerTop: queryTop + queryHeight + queryGap
        readonly property real statusTop: rulerTop + rulerHeight + rulerGap
    }

    Globe {
        anchors.fill: parent
        opacity: .7
    }

    Rectangle {
        anchors.centerIn: parent
        width: dial.diameter
        height: width
        radius: width / 2
        color: Theme.background
        border.color: Theme.border

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.headingTop
            text: "Applications"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontHeading
        }

        TextInput {
            id: input

            objectName: "search"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: dial.sidePadding
            y: dial.queryTop
            height: dial.queryHeight
            focus: true
            color: Theme.text
            selectionColor: Theme.selection
            font.family: Theme.font
            font.pixelSize: Theme.fontQuery
            horizontalAlignment: TextInput.AlignHCenter
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
                anchors.centerIn: parent
                visible: !input.text.length
                text: "Search"
                color: Theme.text
                font: input.font
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.rulerTop
            width: dial.rulerWidth
            height: dial.rulerHeight
            color: Theme.border
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: dial.statusTop
            width: dial.statusWidth
            text: root.statusText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontCaption
        }
    }
}
