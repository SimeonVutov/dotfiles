.pragma library
.import "../model/WidgetDefinition.js" as Base

var ClockDefinition = class extends Base.WidgetDefinition {
    constructor() {
        super({type: "clock", name: "Clock", columns: 8, rows: 6, component: "widgets/ClockWidget.qml"});
    }
};
