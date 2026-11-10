.pragma library
.import "../../model/WidgetDefinition.js" as Base
.import "../../model/Setting.js" as Settings

var MusicDefinition = class extends Base.WidgetDefinition {
    constructor() {
        super({type: "music", name: "Music Player", columns: 6, rows: 4, component: "widgets/music/MusicWidget.qml", settings: [
            new Settings.Setting({key: "artworkSize", label: "Artwork size", kind: "number", minimum: 48, maximum: 320, step: 1, initial: 182}),
            new Settings.Setting({key: "titleSize", label: "Title size", kind: "number", minimum: 12, maximum: 32, step: 1, initial: 24})
        ]});
    }
};
