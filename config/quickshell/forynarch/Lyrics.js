.pragma library

function parse(value) {
    if (typeof value !== "string") return [];
    const offset = /\[offset:([+-]?\d+)\]/i.exec(value);
    const adjustment = offset ? Number(offset[1]) / 1000 : 0;
    const rows = [];
    for (const line of value.slice(0, 200000).split("\n").slice(0, 2000)) {
        const pattern = /\[(\d{1,3}):(\d{2}(?:\.\d+)?)\]/g;
        let stamp, count = 0;
        const text = line.replace(/\[[^\]]*\]/g, "").trim().slice(0, 1000);
        while ((stamp = pattern.exec(line)) !== null && count++ < 8)
            rows.push({t: Math.max(0, Number(stamp[1]) * 60 + Number(stamp[2]) - adjustment), text: text});
        if (!count && line.trim() && !/^\[[a-z]+:/i.test(line))
            rows.push({t: -1, text: line.trim().slice(0, 1000)});
    }
    const timed = rows.filter(row => row.t >= 0);
    return timed.length ? timed.sort((a, b) => a.t - b.t) : rows;
}
