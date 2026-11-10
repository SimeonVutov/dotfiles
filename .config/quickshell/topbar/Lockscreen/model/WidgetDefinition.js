.pragma library
.import "Setting.js" as Settings

var WidgetDefinition = class {
    constructor(options) {
        Object.assign(this, {component: "", required: false}, options);
        this.settings = Settings.common.concat(options.settings || []);
    }

    defaults() {
        const values = {};
        this.settings.forEach(setting => values[setting.key] = setting.initial);
        return values;
    }

    resolve(values) {
        const result = this.defaults();
        return Object.assign(result, values || {});
    }

    validate(values) {
        if (!values || typeof values !== "object" || Array.isArray(values))
            throw new Error("Invalid widget settings.");

        Object.keys(values).forEach(key => {
            const setting = this.settings.find(item => item.key === key);
            if (!setting)
                throw new Error("Unknown widget setting: " + key);

            const error = setting.validate(values[key]);
            if (error)
                throw new Error(error);
        });
    }
};
