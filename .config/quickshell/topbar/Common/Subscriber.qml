import QtQml

QtObject {
    id: root

    property bool active: false
    signal toggled(bool enabled)

    // Tracks the last state reported via toggled, so toggling `active` only
    // fires on a real transition — and releases it if left active on destroy.
    property bool _synced: false

    function _sync() {
        if (_synced === active)
            return;
        _synced = active;
        toggled(active);
    }

    onActiveChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: if (_synced)
        toggled(false)
}
