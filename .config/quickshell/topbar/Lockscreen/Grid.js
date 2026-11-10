.pragma library
.import "WidgetCatalog.js" as Catalog
.import "Animations.js" as Animations

var resolutions = [18, 27, 36, 54, 72].map(columns => ({columns: columns, rows: columns * 2 / 3}));

function copy(value) {
    const serialized = JSON.stringify(value);
    return JSON.parse(serialized);
}

function initial() {
    return {version: 1, columns: 18, rows: 12, animation: Animations.defaults(), widgets: [
        {id: "clock", type: "clock", column: 5, row: 0, columns: 8, rows: 6, settings: Catalog.defaults("clock")},
        {id: "authentication", type: "authentication", column: 6, row: 7, columns: 6, rows: 1, settings: Catalog.defaults("authentication")}
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
    const definition = Catalog.find(widget.type);
    if (!definition)
        return "Unknown widget.";

    if (![widget.column, widget.row, widget.columns, widget.rows].every(Number.isInteger))
        return "Widget sizes and positions must use whole cells.";

    if (widget.columns < 1 || widget.rows < 1 || widget.column < 0 || widget.row < 0
            || widget.column + widget.columns > layout.columns || widget.row + widget.rows > layout.rows)
        return "Keep the whole widget inside the grid.";

    if (widget.columns < (definition.minimumColumns || 1) || widget.rows < (definition.minimumRows || 1))
        return definition.name + " is smaller than its minimum cell span.";

    if (definition.maximumRows && widget.rows > definition.maximumRows)
        return definition.name + " must be exactly " + definition.maximumRows + " row high.";

    if (layout.widgets.some(other => other.id !== widget.id && overlaps(other, widget)))
        return "Those cells are already occupied.";

    return "";
}

function validateSettings(widget) {
    const definition = Catalog.find(widget.type);
    if (!definition)
        throw new Error("Unknown widget.");

    definition.validate(widget.settings);
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

    const next = copy(layout);
    next.animation = Animations.resolve(next.animation);
    return next;
}

function place(layout, widget) {
    const next = copy(layout);
    const index = next.widgets.findIndex(other => other.id === widget.id);
    if (index === -1)
        next.widgets.push(copy(widget));
    else
        next.widgets[index] = copy(widget);

    return validate(next);
}

function migrate(layout) {
    const next = copy(layout);
    const password = next?.widgets?.find(widget => widget.type === "authentication");
    if (password && Number.isInteger(password.row) && Number.isInteger(password.rows) && password.rows > 1) {
        password.row += Math.floor((password.rows - 1) / 2);
        password.rows = 1;
    }

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
