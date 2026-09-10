pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Rectangle {
    id: root

    property string currentTab: ""
    property var tabs: []
    signal selected(string tab)

    readonly property int currentIndex: Math.max(0, tabs.findIndex(tab => tab.value === currentTab))
    readonly property real segmentWidth: tabs.length > 0 ? width / tabs.length : width

    implicitHeight: 38
    radius: 10
    color: Theme.popupSurface

    Rectangle {
        x: 3 + root.currentIndex * root.segmentWidth
        y: 3
        width: root.segmentWidth - 6
        height: parent.height - 6
        radius: 8
        color: Theme.popupBorder

        Behavior on x {
            NumberAnimation {
                duration: Theme.durationFast
                easing.type: Theme.easingEmphasized
            }
        }
    }

    Repeater {
        model: root.tabs

        Item {
            id: tabItem

            required property var modelData
            required property int index

            x: index * root.segmentWidth
            width: root.segmentWidth
            height: root.height

            BarText {
                anchors.centerIn: parent
                text: tabItem.modelData.icon + "   " + tabItem.modelData.label
                color: root.currentTab === tabItem.modelData.value ? Theme.popupText : Theme.popupSubtleText
                font.pixelSize: 13

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFast
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selected(tabItem.modelData.value)
            }
        }
    }
}
