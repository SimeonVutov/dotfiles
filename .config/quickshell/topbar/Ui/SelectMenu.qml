pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Item {
    id: root
    property string title: ""
    property string footerText: ""
    property string currentLabel: "Choose"
    property string currentIcon: ""
    property var options: []
    property string selectedValue: ""
    property bool expanded: false
    property bool interactive: true
    property Item overlayParent: root
    signal selected(string value)
    implicitHeight: 58

    onExpandedChanged: {
        if (expanded) {
            const point = root.mapToItem(overlayParent, 0, height + 6);
            menu.x = point.x;
            menu.y = point.y;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: trigger.containsMouse || root.expanded ? Theme.popupSurface : "transparent"
        opacity: root.interactive ? 1 : 0.5
        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFast
            }
        }
        Rectangle {
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34
            radius: 17
            color: Theme.popupSurface
            BarText {
                anchors.centerIn: parent
                text: root.currentIcon
                font.pixelSize: 16
            }
        }
        Column {
            x: 48
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 22
            spacing: 3
            BarText {
                text: root.title
                color: Theme.popupSubtleText
                font.pixelSize: 11
            }
            BarText {
                width: parent.width
                text: root.currentLabel
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
        BarText {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.chevronDown
            font.pixelSize: 11
            rotation: root.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durationFast
                }
            }
        }
        MouseArea {
            id: trigger
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Reparent into the panel overlay without creating another focus-grab window.
    Rectangle {
        id: menu
        parent: root.overlayParent
        z: 1
        width: root.width
        height: rows.implicitHeight + 8
        radius: 12
        color: Theme.popupBackground
        border.color: Theme.popupBorder
        visible: opacity > 0
        enabled: root.expanded
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.97
        transformOrigin: Item.Top
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }
        Column {
            id: rows
            x: 4
            y: 4
            width: parent.width - 8
            spacing: 2
            Repeater {
                model: root.options
                Rectangle {
                    id: option
                    required property var modelData
                    width: rows.width
                    height: 40
                    radius: 8
                    color: rowMouse.containsMouse || root.selectedValue === modelData.value ? Theme.popupSurface : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durationFast
                        }
                    }
                    BarText {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 24
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                        text: option.modelData.icon + "   " + option.modelData.label
                        elide: Text.ElideRight
                    }
                    BarText {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.selectedValue === option.modelData.value ? Icons.check : ""
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.expanded = false;
                            root.selected(option.modelData.value);
                        }
                    }
                }
            }
            BarText {
                width: parent.width
                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6
                text: root.footerText
                visible: text !== ""
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: Theme.popupSubtleText
            }
        }
    }
}
