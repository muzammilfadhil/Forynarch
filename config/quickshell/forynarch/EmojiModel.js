.pragma library
var symbols = ["©","®","™","°","±","×","÷","≠","≈","≤","≥","∞","√","π","µ","²","³","½","¼","¾","€","£","¥","₹","₩","₿","¢","•","…","—","–","→","←","↑","↓","↔","✓","✕","★","☆","♥","♦","♣","♠","§","¶"];
var faces = ["(づ｡◕‿‿◕｡)づ", "¯\\_(ツ)_/¯", "(╯°□°)╯︵ ┻━┻", "┬─┬ノ( º _ ºノ)", "(•‿•)", "(≧◡≦)", "(ง •̀_•́)ง", "(ಥ﹏ಥ)", "(¬‿¬)", "(☞ﾟヮﾟ)☞", "ʕ•ᴥ•ʔ", "(っ˘з(˘⌣˘ )", ":)", ":D", ";)", ":(", "<3"];
var faceNames=["hug","shrug","table flip angry","table calm","happy smile","happy joy","fight determined","cry sad","smirk","point","bear","kiss","smile","laugh","wink","sad","heart love"];
var symbolNames=["copyright","registered","trademark","degree","plus minus","multiply","divide","not equal","approximately","less equal","greater equal","infinity","square root","pi","micro","squared","cubed","one half","one quarter","three quarters","euro","pound","yen","rupee","won","bitcoin","cent","bullet","ellipsis","em dash","en dash","right arrow","left arrow","up arrow","down arrow","left right arrow","check mark","cross","star filled","star outline","heart","diamond","club","spade","section","paragraph"];
function characters(tab,history,query) {
    var source=tab==="Recent"?history:tab==="Symbols"?symbols:faces;
    return source.map((value,index)=>({value:value,name:tab==="Symbols"?symbolNames[index]:tab==="Kaomoji"?faceNames[index]:value}))
        .filter(row=>(row.name+" "+row.value).toLowerCase().includes(query.trim().toLowerCase()));
}
function search(rows, query, category, tone) {
    var words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    return rows.filter(row => (!category || row.group === category) &&
        words.every(word => (row.name+" "+row.group+" "+row.value).toLowerCase().includes(word)) &&
        (tone === "All" || (tone === "Default" ? !row.name.includes("skin tone") : row.name.includes(tone.toLowerCase()+" skin tone"))));
}
function recent(value, old) {
    return [value].concat(old.filter(item => item !== value)).slice(0,32);
}
