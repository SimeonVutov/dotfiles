.pragma library
.import "WidgetCatalog.js" as Catalog

var resolutions = [18, 27, 36, 54, 72].map(columns => ({columns: columns, rows: columns * 2 / 3}));

function copy(value) {
    const serialized = JSON.stringify(value);
    return JSON.parse(serialized);
}

function initial() {
    return {version: 1, columns: 18, rows: 12, widgets: [
        {id: "clock", type: "clock", column: 5, row: 0, columns: 8, rows: 6, settings: Catalog.defaults("clock")},
        {id: "authentication", type: "authentication", column: 6, row: 7, columns: 6, rows: 3, settings: Catalog.defaults("authentication")}
    ]};
}

function overlaps(a, b) {
    return a.column < b.column + b.columns && a.column + a.columns > b.column
        && a.row < b.row + b.rows && a.row + a.rows > b.row;
}

function contains(widget, column, row) {
    return column >= widget.column && column < widget.column + widget.columns
        && row >= widget.row && row < widget.row + widget.rows;
}

function occupied(layout, column, row, excluding) {
    const widgets = layout.widgets.filter(widget => widget.id !== excluding);
    return widgets.some(widget => contains(widget, column, row));
}

function placementError(layout, widget) {
    if (!Catalog.find(widget.type))
        return "Unknown widget.";

    if (![widget.column, widget.row, widget.columns, widget.rows].every(Number.isInteger))
        return "Widget sizes and positions must use whole cells.";

    if (widget.columns < 1 || widget.rows < 1 || widget.column < 0 || widget.row < 0
            || widget.column + widget.columns > layout.columns || widget.row + widget.rows > layout.rows)
        return "Keep the whole widget inside the grid.";

    if (widget.type === "authentication" && (widget.columns < 4 || widget.rows < 3))
        return "Unlock needs at least 4 × 3 cells.";

    if (layout.widgets.some(other => other.id !== widget.id && overlaps(other, widget)))
        return "Those cells are already occupied.";

    return "";
}

function validateSettings(widget) {
    if (!widget.settings || typeof widget.settings !== "object" || Array.isArray(widget.settings))
        throw new Error("Invalid widget settings.");

    const controls = Catalog.controls(widget.type);
    Object.keys(widget.settings).forEach(key => {
        const setting = controls.find(control => control.key === key);
        const value = widget.settings[key];
        if (!setting)
            throw new Error("Unknown widget setting: " + key);

        if (setting.kind === "color" && (typeof value !== "string" || !/^#[0-9a-f]{6}$/i.test(value)))
            throw new Error("Use a six-digit hex color.");

        if (setting.kind === "number" && (typeof value !== "number" || !Number.isFinite(value)
                || value < setting.minimum || value > setting.maximum))
            throw new Error("Setting outside its supported range.");
    });
}

function validate(layout) {
    if (!layout || layout.version !== 1 || !Array.isArray(layout.widgets))
        throw new Error("Unsupported lockscreen layout.");

    if (!Number.isInteger(layout.columns) || !Number.isInteger(layout.rows)
            || layout.columns < 9 || layout.rows < 6 || layout.columns > 72 || layout.rows > 48
            || layout.columns * 2 !== layout.rows * 3)
        throw new Error("Unsupported grid resolution.");

    if (layout.widgets.filter(widget => widget.type === "authentication").length !== 1)
        throw new Error("The password widget is required.");

    const ids = new Set();
    const types = new Set();
    layout.widgets.forEach(widget => {
        if (typeof widget.id !== "string" || !/^[a-z][a-z0-9-]*$/.test(widget.id) || ids.has(widget.id) || types.has(widget.type))
            throw new Error("Widget identities must be unique.");

        ids.add(widget.id);
        types.add(widget.type);

        const error = placementError(layout, widget);
        if (error)
            throw new Error(error);

        validateSettings(widget);
    });

    return copy(layout);
}

function place(layout, widget) {
    const next = copy(layout);
    next.widgets = next.widgets.filter(other => other.id !== widget.id);
    next.widgets.push(copy(widget));
    return validate(next);
}

function remove(layout, id) {
    const next = copy(layout);
    next.widgets = next.widgets.filter(widget => widget.id !== id);
    return validate(next);
}

function resize(layout, columns, rows) {
    const next = copy(layout);
    next.columns = columns;
    next.rows = rows;

    // Keep cell spans while preserving screen-space centres. A denser grid
    // shrinks widgets instead of silently growing their configured spans.
    next.widgets.forEach(widget => {
        const column = Math.round((widget.column + widget.columns / 2) * columns / layout.columns - widget.columns / 2);
        const row = Math.round((widget.row + widget.rows / 2) * rows / layout.rows - widget.rows / 2);
        widget.column = Math.max(0, Math.min(columns - widget.columns, column));
        widget.row = Math.max(0, Math.min(rows - widget.rows, row));
    });

    return validate(next);
}
