import QtQuick

Item {
    id: card

    required property string src
    required property string preview
    required property string type
    required property string name

    required property bool matchesFilter
    required property var appearance
    required property var palette
    signal chosen

    readonly property bool currentItem: ListView.isCurrentItem
    readonly property bool isVideo: card.type === "video"
    property bool isApplied: false
    readonly property real targetW: currentItem ? card.appearance.expandedCardWidth : card.appearance.collapsedCardWidth
    readonly property real targetH: currentItem ? card.appearance.expandedCardHeight : card.appearance.cardHeight

    width: matchesFilter ? (targetW + card.appearance.cardSpacing) : 0
    height: matchesFilter ? targetH : 0
    visible: width > 1 && height > 1
    opacity: matchesFilter ? (currentItem ? 1.0 : 0.55) : 0.0
    z: currentItem ? 10 : 1

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    anchors.verticalCenterOffset: 0

    function horizontalSkew(amount) {
        return Qt.matrix4x4(1, amount, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
    }

    Behavior on width {
        NumberAnimation {
            duration: card.appearance.cardTransitionDuration
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: card.appearance.cardTransitionDuration
            easing.type: Easing.InOutQuad
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: card.appearance.cardFadeDuration
            easing.type: Easing.InOutQuad
        }
    }

    Item {
        id: inner
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: ((card.appearance.cardHeight - height) / 2) * card.appearance.skewFactor
        width: parent.width > 0 ? parent.width * (card.targetW / (card.targetW + card.appearance.cardSpacing)) : 0
        height: parent.height

        transform: Matrix4x4 {
            matrix: card.horizontalSkew(card.appearance.skewFactor)
        }

        MouseArea {
            anchors.fill: parent
            enabled: card.matchesFilter
            cursorShape: Qt.PointingHandCursor
            onClicked: card.chosen()
        }

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: Qt.rgba(0, 0, 0, card.currentItem ? 0.28 : 0.18)
            scale: 1.02
        }

        Item {
            anchors.fill: parent
            anchors.margins: card.appearance.borderWidth
            clip: true

            Rectangle {
                anchors.fill: parent
                color: card.appearance.placeholderBackdrop
            }

            Image {
                id: thumb
                anchors.centerIn: parent
                width: card.appearance.expandedCardWidth + card.appearance.expandedCardHeight * Math.abs(card.appearance.skewFactor) + card.appearance.thumbnailOverscan
                height: card.appearance.expandedCardHeight
                fillMode: Image.PreserveAspectCrop
                source: card.preview ? ("file://" + card.preview) : ""
                sourceSize.width: Math.max(card.appearance.thumbnailMinWidth, Math.round(width * card.appearance.thumbnailResolutionScale))
                sourceSize.height: Math.max(card.appearance.thumbnailMinHeight, Math.round(height * card.appearance.thumbnailResolutionScale))
                asynchronous: true
                smooth: true
                mipmap: true

                transform: Matrix4x4 {
                    matrix: card.horizontalSkew(-card.appearance.skewFactor)
                }

                Rectangle {
                    anchors.fill: parent
                    visible: thumb.status !== Image.Ready
                    color: Qt.rgba(card.palette.surface0.r, card.palette.surface0.g, card.palette.surface0.b, 0.65)
                }
            }

            Rectangle {
                visible: card.isVideo
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 10
                }
                width: 34
                height: 34
                radius: 8
                color: card.appearance.badgeScrim

                transform: Matrix4x4 {
                    matrix: card.horizontalSkew(-card.appearance.skewFactor)
                }

                Canvas {
                    anchors.fill: parent
                    anchors.margins: 9
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.fillStyle = "#EEFFFFFF";
                        ctx.beginPath();
                        ctx.moveTo(3, 0);
                        ctx.lineTo(14, 7);
                        ctx.lineTo(3, 14);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
            }

            Rectangle {
                visible: card.isApplied
                anchors {
                    top: parent.top
                    left: parent.left
                    margins: 10
                }
                width: 88
                height: 28
                radius: 8
                color: Qt.rgba(card.palette.green.r, card.palette.green.g, card.palette.green.b, 0.92)

                transform: Matrix4x4 {
                    matrix: card.horizontalSkew(-card.appearance.skewFactor)
                }

                Text {
                    anchors.centerIn: parent
                    text: "Current"
                    color: card.appearance.appliedBadgeInk
                    font.pixelSize: 13
                    font.bold: true
                }
            }

            Rectangle {
                visible: card.currentItem
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 38
                color: card.appearance.nameplateScrim

                transform: Matrix4x4 {
                    matrix: card.horizontalSkew(-card.appearance.skewFactor)
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 22
                    text: card.name
                    color: card.palette.text
                    font.pixelSize: 16
                    font.bold: true
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
