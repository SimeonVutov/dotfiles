import QtQuick
import qs.Lockscreen as Lock
import "../../Lockscreen/Grid.js" as Grid
import "../../Lockscreen/WidgetCatalog.js" as Catalog

Item {
    id: root

    property alias store: storage
    readonly property var layout: storage.layout
    readonly property bool ready: storage.ready && !storage.saving
    readonly property var available: Catalog.widgets.filter(definition => !layout.widgets.some(widget => widget.type === definition.type))
    property string selected: ""
    property var moving: null
    property var previewWidget: null
    property int grabColumn: 0
    property int grabRow: 0
    property string error: ""
    readonly property string status: error || storage.error
    signal rejected

    function beginNew(type) {
        const definition = Catalog.find(type);
        if (!ready || !definition || layout.widgets.some(widget => widget.type === type))
            return;

        moving = {
            id: type,
            type: type,
            column: 0,
            row: 0,
            columns: definition.columns,
            rows: definition.rows,
            settings: Catalog.defaults(type)
        };
        grabColumn = Math.floor(moving.columns / 2);
        grabRow = Math.floor(moving.rows / 2);
        error = "";
    }

    function beginMove(id, column, row) {
        const widget = layout.widgets.find(item => item.id === id);
        if (!ready || !widget)
            return;

        selected = id;
        moving = Grid.copy(widget);
        grabColumn = column === undefined ? Math.floor(widget.columns / 2) : column - widget.column;
        grabRow = row === undefined ? Math.floor(widget.rows / 2) : row - widget.row;
        error = "";
    }

    function moveTo(column, row) {
        if (!moving)
            return;

        const next = Grid.copy(moving);
        next.column = column - grabColumn;
        next.row = row - grabRow;
        moving = next;
    }

    function place() {
        if (!moving || !ready)
            return;

        if (saveWidget(moving)) {
            selected = moving.id;
            moving = null;
        }
    }

    function saveWidget(widget) {
        try {
            const next = Grid.place(layout, widget);
            error = "";
            return storage.save(next);
        } catch (exception) {
            previewWidget = null;
            error = exception.message;
            rejected();
            return false;
        }
    }

    function updateWidget(id, changes) {
        if (!ready)
            return;

        const widget = layout.widgets.find(item => item.id === id);
        if (!widget)
            return;

        const next = Object.assign(Grid.copy(widget), changes);
        saveWidget(next);
    }

    function updateSetting(id, key, value) {
        const widget = layout.widgets.find(item => item.id === id);
        if (!widget)
            return;

        const settings = Object.assign({}, widget.settings);
        settings[key] = value;
        updateWidget(id, {
            settings: settings
        });
    }

    function previewSetting(id, key, value) {
        const widget = layout.widgets.find(item => item.id === id);
        if (!widget)
            return;

        const setting = Catalog.controls(widget.type).find(control => control.key === key);
        if (!setting?.livePreview)
            return;

        const next = Grid.copy(previewWidget?.id === id ? previewWidget : widget);
        next.settings[key] = value;
        try {
            Grid.validateSettings(next);
            previewWidget = next;
        } catch (exception) {
            // Incomplete input, such as a partially typed color, is not renderable.
            previewWidget = null;
        }
    }

    function removeWidget(id) {
        const widget = layout.widgets.find(item => item.id === id);
        if (!ready || !widget || Catalog.find(widget.type).required)
            return;

        if (storage.save(Grid.remove(layout, id))) {
            selected = "";
            moving = null;
        }
    }

    function resizeGrid(columns, rows) {
        if (!ready || moving)
            return;

        try {
            const next = Grid.resize(layout, columns, rows);
            error = "";
            storage.save(next);
        } catch (exception) {
            error = "Cannot resize the grid: " + exception.message;
            rejected();
        }
    }

    function cancelMove() {
        moving = null;
        previewWidget = null;
        error = "";
    }

    Lock.LayoutStore {
        id: storage
        onSaved: root.previewWidget = null
        onSaveFailed: root.previewWidget = null
    }
}
