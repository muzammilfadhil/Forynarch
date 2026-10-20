import QtQuick
import Quickshell
import "ControlCenterLayout.js" as Controls
import "PanelMetrics.js" as Metrics

ShellRoot {
    id: test
    Timer { interval: 30; running: true; onTriggered: test.run() }
    function check(condition, message) {
        if (!condition) throw new Error(message);
    }
    function checkLayout(ids) {
        const plan = Controls.layout(ids);
        const occupied = new Set();
        for (const tile of plan.items) {
            check(tile.col >= 0 && tile.col + tile.w <= 4, "Tile outside columns");
            check(tile.row >= 0 && tile.row + tile.h <= plan.rows, "Tile outside rows");
            for (let y = tile.row; y < tile.row + tile.h; y++) {
                for (let x = tile.col; x < tile.col + tile.w; x++) {
                    const cell = x + ":" + y;
                    check(!occupied.has(cell), "Overlapping tiles");
                    occupied.add(cell);
                }
            }
        }
        check(plan.items.length === ids.length, "Missing tile");
    }
    function run() {
        try {
            check(Controls.valid(["sound", "unknown", "sound", "wifi"]).join() === "sound,wifi", "Unsafe control IDs");
            check(Controls.layout([]).items.length === 0, "Empty layout");
            const original = Controls.layout(Controls.defaults);
            check(original.rows === 5, "Five-row layout without recording");
            check(original.items.find(x => x.id === "nowplaying").col === 2, "Music placement");
            let seed = 419;
            for (let i = 0; i < 100; i++) {
                const ids = Controls.defaults.slice();
                for (let j = ids.length - 1; j > 0; j--) {
                    seed = (seed * 16807) % 2147483647;
                    const k = seed % (j + 1);
                    [ids[j], ids[k]] = [ids[k], ids[j]];
                }
                checkLayout(ids.slice(0, i % (ids.length + 1)));
            }
            const reordered = Controls.reorder(Controls.defaults, "sound", "wifi");
            check(reordered[0] === "sound" && new Set(reordered).size === 9, "Reorder loses controls");
            for (const field of Metrics.fields) {
                for (const value of [NaN, Infinity, "32", null]) {
                    check(Metrics.valid({[field.key]: value})[field.key] === field.value, "Invalid preference accepted");
                }
                check(Metrics.valid({[field.key]: -999})[field.key] === field.min, "Lower bound");
                check(Metrics.valid({[field.key]: 999})[field.key] === field.max, "Upper bound");
                check(Metrics.update({}, field.key, field.max + 1) === null, "Unsafe update accepted");
            }
            check(Metrics.update({}, "unknown", 4) === null, "Unknown preference accepted");
            console.log("PASS panel layout: 100 packing permutations, control validation, 20 metric boundaries");
            Qt.quit();
        } catch (error) {
            console.error("FAIL panel layout: " + error.message);
            Qt.exit(1);
        }
    }
}
