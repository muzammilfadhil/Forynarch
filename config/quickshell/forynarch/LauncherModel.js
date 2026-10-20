.pragma library
function rank(entry, query, defaultTerminal) {
    if (entry.noDisplay) return -1;
    const name = (entry.name || "").toLowerCase();
    const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    const preferred = entry.id && entry.id.replace(/\.desktop$/, "") === (defaultTerminal || "").replace(/\.desktop$/, "");
    if (!terms.length) return preferred ? 10 : (name.includes("file manager") ? 9 : 1);
    if (preferred && terms.every(term => "terminal".includes(term))) return 1000;
    const extra = [entry.genericName, entry.comment].concat(entry.keywords || []).join(" ").toLowerCase();
    let score = 0;
    for (const term of terms) {
        if (name === term) score += 200;
        else if (name.startsWith(term)) score += 100;
        else if (name.includes(term)) score += 60;
        else if (extra.includes(term)) score += 20;
        else return -1;
    }
    return score;
}
function search(entries, query, defaultTerminal) {
    return entries.map(entry => ({entry:entry, score:rank(entry,query,defaultTerminal)}))
        .filter(hit => hit.score >= 0)
        .sort((a,b) => b.score-a.score || a.entry.name.localeCompare(b.entry.name))
        .map(hit=>hit.entry);
}
