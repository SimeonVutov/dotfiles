const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function load(name, imports = {}) {
    const code = fs.readFileSync(path.join(__dirname, name), 'utf8').replace(/^\.(?:pragma|import).*$/gm, '');
    const context = vm.createContext({...imports});
    vm.runInContext(code, context, {filename: name});
    return context;
}

const Catalog = load('WidgetCatalog.js');
const Grid = load('Grid.js', {Catalog});
const initial = Grid.initial();
assert.doesNotThrow(() => Grid.validate(initial));

function music(changes = {}) {
    return {id: 'music', type: 'music', column: 0, row: 10, columns: 4, rows: 2,
        settings: Catalog.defaults('music'), ...changes};
}

const placed = Grid.place(initial, music());
assert.equal(placed.widgets.length, 3);
assert.equal(initial.widgets.length, 2);
assert.throws(() => Grid.place(initial, music({column: 6, row: 7})), /occupied/);
assert.throws(() => Grid.place(initial, music({column: 16})), /inside/);
assert.throws(() => Grid.place(initial, music({row: -1})), /inside/);
assert.throws(() => Grid.place(initial, music({rows: .5})), /whole/);
assert.throws(() => Grid.place(initial, music({columns: 0})), /inside/);
assert.throws(() => Grid.remove(initial, 'authentication'), /password/);
assert.throws(() => Grid.place(initial, {...initial.widgets[1], rows: 1}), /at least/);
assert.equal(Grid.placementError(placed, music({column: 1})), '');
assert.equal(Grid.occupied(placed, 0, 10, 'music'), false);
assert.equal(Grid.occupied(placed, 6, 7, 'music'), true);
assert.equal(Grid.remove(placed, 'music').widgets.length, 2);

const resized = Grid.place(placed, music({columns: 5}));
assert.equal(resized.widgets.find(widget => widget.id === 'music').columns, 5);
assert.throws(() => Grid.place(placed, music({settings: {backgroundOpacity: 2}})), /range/);
assert.throws(() => Grid.place(placed, music({settings: {textColor: 'transparent'}})), /hex/);
assert.throws(() => Grid.place(placed, music({type: '../../unsafe.qml'})), /Unknown/);
assert.throws(() => Grid.place(placed, music({settings: {component: '/tmp/unsafe.qml'}})), /Unknown/);
assert.throws(() => Grid.validate({...initial, version: 900}), /Unsupported/);
assert.throws(() => Grid.validate({...initial, widgets: [initial.widgets[1], initial.widgets[1]]}), /password/);
assert.equal(Grid.validate(JSON.parse(JSON.stringify(placed))).widgets.length, 3);

console.log('PASS grid placement, movement, collisions, bounds, spans, settings, required authentication, and saved-layout validation');
