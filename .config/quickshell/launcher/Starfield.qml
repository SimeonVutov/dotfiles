import QtQuick

// The stars behind the flight. The field is drawn twice, one copy above the
// other, so scrolling it is a single move of the pair, with no per-star work.
Item {
    id: root

    // In screen heights; positive moves the stars down.
    property real shift: 0
    // 0..1, stretches the stars into speed streaks.
    property real streak: 0
    property real level: 0

    readonly property int count: 110

    visible: level > 0
    opacity: level
    clip: true

    Item {
        width: root.width
        height: root.height * 2
        y: (((root.shift % 1) + 1) % 1 - 1) * root.height

        Repeater {
            model: 2

            Item {
                required property int index

                y: index * root.height
                width: root.width
                height: root.height

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index

                        // Coprime strides spread the stars without a position table.
                        x: ((index * 197 + 61) % 997) / 997 * root.width
                        y: ((index * 109 + 37) % 991) / 991 * root.height
                        width: index % 11 === 0 ? 2.2 : index % 4 === 0 ? 1.6 : 1.1
                        height: width + root.streak * (8 + index % 6 * 5)
                        radius: width / 2
                        color: index % 7 === 0 ? "#cfe0ff" : index % 9 === 0 ? "#fff1d6" : "#ffffff"
                        opacity: .25 + index % 5 * .17
                    }
                }
            }
        }
    }
}
