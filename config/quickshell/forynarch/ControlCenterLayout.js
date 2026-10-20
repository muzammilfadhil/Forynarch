.pragma library

// Adapted from 0-ss/MacShell MacBar.qml, MIT. See MACSHELL-SOURCES.md.
var catalog = [
    {id:"wifi",label:"Wi-Fi",glyph:"wifi",w:2,h:1},
    {id:"bluetooth",label:"Bluetooth",glyph:"bluetooth",w:1,h:1},
    {id:"airplane",label:"Airplane Mode",glyph:"airplane",w:1,h:1},
    {id:"focus",label:"Focus",glyph:"moon",w:2,h:1},
    {id:"nightshift",label:"Night Shift",glyph:"nightshift",w:1,h:1},
    {id:"keepawake",label:"Keep Awake",glyph:"coffee",w:1,h:1},
    {id:"nowplaying",label:"Now Playing",glyph:"note",w:2,h:2},
    {id:"display",label:"Display",glyph:"sun",w:4,h:1},
    {id:"sound",label:"Sound",glyph:"speaker",w:4,h:1}
];
var defaults = ["wifi","nowplaying","bluetooth","airplane","focus","nightshift","keepawake","display","sound"];

function valid(ids) {
    if (!Array.isArray(ids)) return defaults.slice();
    return [...new Set(ids.filter(id=>catalog.some(d=>d.id===id)))].slice(0,catalog.length);
}

function layout(ids) {
    let occupied=[],items=[],rows=0;
    for (const id of valid(ids)) {
        const d=catalog.find(d=>d.id===id);
        let placed=false;
        for(let row=0;!placed;row++) {
            for(let col=0;col+d.w<=4;col++) {
                let free=true;
                for(let y=row;y<row+d.h;y++)for(let x=col;x<col+d.w;x++)if(occupied[y]?.[x])free=false;
                if(!free)continue;
                for(let y=row;y<row+d.h;y++) {
                    if(!occupied[y])occupied[y]=[];
                    for(let x=col;x<col+d.w;x++)occupied[y][x]=true;
                }
                items.push({id:d.id,col:col,row:row,w:d.w,h:d.h});
                rows=Math.max(rows,row+d.h);placed=true;break;
            }
        }
    }
    return {items:items,rows:rows};
}

function reorder(ids,id,target) {
    const next=valid(ids).filter(value=>value!==id);
    if(!catalog.some(d=>d.id===id))return next;
    const index=next.indexOf(target);
    next.splice(index<0?next.length:index,0,id);
    return next;
}
