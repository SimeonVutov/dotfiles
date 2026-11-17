.pragma library
.import "../../model/WidgetDefinition.js" as Base
.import "../../model/Setting.js" as Settings

var PasswordDefinition = class extends Base.WidgetDefinition {
    constructor() {
        super({type: "authentication", name: "Unlock", columns: 6, rows: 1, minimumColumns: 4, minimumRows: 1, maximumRows: 1, required: true, settings: [
            new Settings.Setting({key: "attemptLimit", label: "Unsuccessful attempts", kind: "number", control: "stepper", minimum: 1, maximum: 20, integer: true, initial: 3}),
            new Settings.Setting({key: "retryTimeoutMinutes", label: "Retry timeout (minutes)", kind: "number", control: "stepper", minimum: 1, maximum: 60, integer: true, initial: 5})
        ]});
    }
};
