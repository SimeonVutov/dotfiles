.pragma library
.import "model/WidgetDefinition.js" as Base
.import "widgets/ClockDefinition.js" as Clock
.import "widgets/music/MusicDefinition.js" as Music
.import "widgets/password/PasswordDefinition.js" as Password

// Only trusted definitions can supply component paths and setting implementations.
var widgets = [
    new Password.PasswordDefinition(),
    new Clock.ClockDefinition(),
    new Music.MusicDefinition(),
    new Base.WidgetDefinition({type: "calendar", name: "Calendar", columns: 4, rows: 4}),
    new Base.WidgetDefinition({type: "tasks", name: "Tasks", columns: 3, rows: 4}),
    new Base.WidgetDefinition({type: "progress", name: "Progress", columns: 4, rows: 2})
];

function find(type) {
    const definition = widgets.find(widget => widget.type === type);
    return definition || null;
}

function controls(type) {
    const definition = find(type);
    return definition ? definition.settings : [];
}

function defaults(type) {
    const definition = find(type);
    return definition ? definition.defaults() : {};
}
