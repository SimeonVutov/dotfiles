import QtQuick
import qs.Common

Rectangle {
    id: root

    property string currentTab: "wifi"
    signal selected(string tab)

    implicitHeight: 38
    radius: 10
    color: Theme.popupSurface

    Rectangle {
        x: root.currentTab === "wifi" ? 3 : root.width / 2
        y: 3
        width: root.width / 2 - 3
        height: root.height - 6
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
        model: [
            {
                tab: "wifi",
                label: "Wi-Fi",
                icon: Icons.wifi
            },
            {
                tab: "bluetooth",
                label: "Bluetooth",
                icon: Icons.bluetooth
            }
        ]

        Item {
            required property var modelData
            required property int index

            x: index * root.width / 2
            width: root.width / 2
            height: root.height

            BarText {
                anchors.centerIn: parent
                text: modelData.icon + "   " + modelData.label
                color: root.currentTab === modelData.tab ? Theme.popupText : Theme.popupSubtleText
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
                onClicked: root.selected(modelData.tab)
            }
        }
    }
}
