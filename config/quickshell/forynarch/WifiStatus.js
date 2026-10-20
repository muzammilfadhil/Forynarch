.pragma library

// nmcli escapes separators and backslashes; SSIDs can contain either.
function rows(text) {
    return text.split("\n").filter(line => line.length).map(function(line) {
        var cells = [], cell = "", escaped = false;
        for (var i = 0; i < line.length; i++) {
            var ch = line[i];
            if (escaped) { cell += ch; escaped = false; }
            else if (ch === "\\") escaped = true;
            else if (ch === ":") { cells.push(cell); cell = ""; }
            else cell += ch;
        }
        if (escaped) cell += "\\";
        cells.push(cell);
        return cells;
    });
}

function device(text) {
    var adapters = rows(text).filter(row => row.length === 4 && row[1] === "wifi");
    var connected = adapters.find(row => row[2].indexOf("connected") === 0);
    var active = connected || adapters.find(row => row[2].indexOf("connecting") === 0) || adapters[0];
    return { available: adapters.length > 0, connected: !!connected,
        connecting: !!active && active[2].indexOf("connecting") === 0,
        name: active ? active[0] : "", connection: connected ? connected[3] : "" };
}

function ssid(text, deviceName) {
    var active = rows(text).find(row => row.length === 3 && row[0] === deviceName && row[1] === "*");
    return active ? active[2] : "";
}
