.pragma library

var Setting = class {
    constructor(options) {
        Object.assign(this, {livePreview: false, control: options.kind === "color" ? "color" : "slider"}, options);
    }

    validate(value) {
        if (this.kind === "color")
            return typeof value === "string" && /^#(?:[0-9a-f]{6}|[0-9a-f]{8})$/i.test(value) ? "" : "Use a hex color with an optional alpha channel.";

        if (this.kind === "number") {
            if (typeof value !== "number" || !Number.isFinite(value) || value < this.minimum || value > this.maximum)
                return "Setting outside its supported range.";

            if (this.integer && !Number.isInteger(value))
                return "Use a whole number.";
        }

        return "";
    }
};

var common = [
    new Setting({key: "backgroundOpacity", label: "Background opacity", kind: "number", minimum: 0, maximum: 1, step: .05, initial: 0, livePreview: true}),
    new Setting({key: "backgroundColor", label: "Background color", kind: "color", initial: "#1a1a1a", livePreview: true}),
    new Setting({key: "textColor", label: "Text color", kind: "color", initial: "#ffffff", livePreview: true}),
    new Setting({key: "cornerRadius", label: "Corner radius", kind: "number", minimum: 0, maximum: 48, step: 1, initial: 18, livePreview: true})
];
