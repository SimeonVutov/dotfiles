.pragma library

var options = [
    {type: "none", name: "None", x: 0, y: 0},
    {type: "fade", name: "Fade", x: 0, y: 0},
    {type: "swipe-up", name: "Swipe Up", x: 0, y: 1},
    {type: "swipe-down", name: "Swipe Down", x: 0, y: -1},
    {type: "swipe-left", name: "Swipe Left", x: 1, y: 0},
    {type: "swipe-right", name: "Swipe Right", x: -1, y: 0},
    {type: "zoom-in", name: "Zoom In", x: 0, y: 0}
];

function defaults() {
    return {type: "fade", duration: 400};
}

function resolve(settings) {
    if (settings !== undefined && (!settings || typeof settings !== "object" || Array.isArray(settings)))
        throw new Error("Invalid lockscreen animation settings.");

    const result = Object.assign(defaults(), settings || {});
    if (!options.some(option => option.type === result.type))
        throw new Error("Unknown lockscreen animation.");

    if (!Number.isInteger(result.duration) || result.duration < 50 || result.duration > 10000)
        throw new Error("Animation duration must be between 0.05 and 10 seconds.");

    return result;
}
