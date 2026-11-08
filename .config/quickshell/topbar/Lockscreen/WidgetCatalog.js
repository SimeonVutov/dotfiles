.pragma library

// Components are trusted code registered here, never paths taken from saved layouts.
// A component receives widgetSettings and may use its full allotted rectangle.
var widgets = [
    {type: "authentication", name: "Unlock", columns: 6, rows: 3, required: true, component: ""},
    {type: "clock", name: "Clock", columns: 8, rows: 6, component: "widgets/ClockWidget.qml"},
    {type: "music", name: "Music Player", columns: 4, rows: 2, component: ""},
    {type: "calendar", name: "Calendar", columns: 4, rows: 4, component: ""},
    {type: "tasks", name: "Tasks", columns: 3, rows: 4, component: ""},
    {type: "progress", name: "Progress", columns: 4, rows: 2, component: ""}
];

// Add widget-specific controls here using the same declarative setting contract.
var settings = [
    {key: "backgroundOpacity", livePreview: true, label: "Background opacity", kind: "number", minimum: 0, maximum: 1, step: .05, initial: 0},
    {key: "backgroundColor", livePreview: true, label: "Background color", kind: "color", initial: "#1a1a1a"},
    {key: "textColor", livePreview: true, label: "Text color", kind: "color", initial: "#ffffff"},
    {key: "cornerRadius", livePreview: true, label: "Corner radius", kind: "number", minimum: 0, maximum: 48, step: 1, initial: 18}
];

function find(type) {
    const definition = widgets.find(widget => widget.type === type);
    return definition || null;
}
function controls(type) {
    const definition = find(type);
    return settings.concat(definition?.settings || []);
}
function defaults(type) {
    const result = {};
    controls(type).forEach(setting => result[setting.key] = setting.initial);
    return result;
}
