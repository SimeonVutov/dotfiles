import QtQuick
import qs.Common

Item {
    id: root

    property var screen: null
    property string moduleViewId: ""
    property var autoHiddenItems: []
    property string autoView: ""
    property real preferredWidth: implicitWidth
    readonly property bool configurable: !!Config.moduleViews[moduleViewId]

    function widthForCompression(state) {
        return state.hidden ? 0 : preferredWidth;
    }

    implicitWidth: childrenRect.width
    implicitHeight: childrenRect.height
    clip: true

    PopupHost {
        id: viewHost
        enabled: root.configurable
        popup: Component {
            ModuleViewMenu {
                moduleAnchor: root
                moduleId: root.moduleViewId
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: root.configurable
        onTapped: viewHost.toggle()
    }
}
