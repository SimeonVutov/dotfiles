import QtQuick
import Quickshell

// Base type for everything that can sit on the bar.
//
// The contract is deliberately tiny: inherit this, set implicitWidth (and
// implicitHeight if you're not using a Pill), and you're a module. `screen` is
// injected by the bar, so a module can tell which monitor it's drawn on
// without reaching back through parents.
Item {
    id: root

    // The ShellScreen this instance is rendered on.
    property var screen: null

    // Set by the bar so a module can tell where it sits, which is what a
    // future drag-and-drop editor would reorder.
    property string moduleId: ""
    property string section: ""

    // Modules size themselves from whatever they contain, so dropping a Pill
    // inside is enough to get the geometry right.
    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
}
