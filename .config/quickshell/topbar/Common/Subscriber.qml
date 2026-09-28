import QtQml

QtObject {
    id: root

    property bool active: false
    property var metrics: []
    signal toggled(bool enabled, var metrics)

    // Tracks the last state reported via toggled, so toggling `active` only
    // fires on a real transition — and releases it if left active on destroy.
    property bool _synced: false
    property var _syncedMetrics: []

    function _sync() {
        const nextMetrics = active ? metrics.slice() : [];
        const metricsUnchanged = _syncedMetrics.length === nextMetrics.length && _syncedMetrics.every((metric, index) => metric === nextMetrics[index]);
        if (_synced === active && metricsUnchanged)
            return;
        if (_synced)
            toggled(false, _syncedMetrics);
        _synced = active;
        _syncedMetrics = nextMetrics;
        if (_synced)
            toggled(true, _syncedMetrics);
    }

    onActiveChanged: _sync()
    onMetricsChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: if (_synced)
        toggled(false, _syncedMetrics)
}
