import QtQuick
import Quickshell

Item {
    id: root

    property Component popup
    property var pendingAction: null

    function use(action) {
        if (loader.item) {
            action(loader.item);
            return;
        }

        pendingAction = action;
        loader.active = true;
    }

    function toggle() {
        use(item => item.toggle());
    }

    function showTab(tab) {
        use(item => item.showTab(tab));
    }

    implicitWidth: 0
    implicitHeight: 0

    LazyLoader {
        id: loader
        component: root.popup
        onItemChanged: {
            if (!item || !root.pendingAction)
                return;
            const action = root.pendingAction;
            root.pendingAction = null;
            action(item);
        }
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (!target.visible && !root.pendingAction)
                loader.active = false;
        }
    }
}
