.pragma library
var keys = ["clock", "calendar", "greeting", "media", "digital", "focus", "system", "battery", "launchpad", "shortcuts"];
var heights = {clock:224, calendar:130, greeting:94, media:130, digital:112, focus:158, system:112, battery:112, launchpad:154, shortcuts:156};
function custom(key) { return /^custom:[a-z][a-z0-9-]{0,39}:[a-z][a-z0-9-]{0,39}$/.test(key); }
function height(key, extra) { return extra?.[key] || heights[key] || 112; }
function valid(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return {};
    var clean = {};
    Object.keys(value).slice(0, 24).forEach(function(output) {
        if (!output || output.length > 160) return;
        var positions = {};
        Object.keys(value[output] || {}).filter(key=>keys.includes(key)||custom(key)).slice(0,34).forEach(function(key) {
            var p = value[output]?.[key];
            if (p && Number.isFinite(p.x) && Number.isFinite(p.y))
                positions[key] = {x:Math.max(0,Math.min(1,p.x)),y:Math.max(0,Math.min(1,p.y))};
        });
        clean[output] = positions;
    });
    return clean;
}
function position(layout, output, key, index, width, screenHeight, scale, right, order, extra) {
    var w = 224*scale, h = height(key,extra)*scale;
    var p = layout[output]?.[key];
    var y = 96;
    var column=0, sequence=order||keys;
    for(var i=0;i<index;i++){y+=(height(sequence[i],extra)+12)*scale;if(y+height(sequence[i+1]||key,extra)*scale>screenHeight-16){y=96;column++;}}
    var x=right?width-w-40-column*(w+24):40+column*(w+24);
    return {x:Math.max(0,Math.min(width-w,p ? p.x*Math.max(0,width-w) : x)),
    y:Math.max(64,Math.min(Math.max(64,screenHeight-h-16),p ? p.y*Math.max(0,screenHeight-h) : y))};
}
function moved(layout, output, key, x, y, width, screenHeight, scale, snap, extra) {
    if ((!keys.includes(key)&&!custom(key)) || !Number.isFinite(x) || !Number.isFinite(y)) return layout;
    if (snap) {x=Math.round(x/24)*24;y=Math.round(y/24)*24;}
    var next = JSON.parse(JSON.stringify(layout));
    if (!next[output]) next[output]={};
    next[output][key]={x:Math.max(0,Math.min(1,x/Math.max(1,width-224*scale))),
                      y:Math.max(0,Math.min(1,y/Math.max(1,screenHeight-height(key,extra)*scale)))};
    return next;
}
function preset(layout, output, name, width, screenHeight, scale, order, extra) {
    var next=JSON.parse(JSON.stringify(layout));next[output]={};
    var sequence=order||keys;
    sequence.forEach(function(key,index) {
        var side=name==="balanced"?sequence.filter((key,i)=>i%2===index%2):sequence;
        var point=position({},output,key,side.indexOf(key),width,screenHeight,scale,name==="right"||(name==="balanced"&&index%2===1),side,extra);
        next=moved(next,output,key,point.x,point.y,width,screenHeight,scale,true,extra);
    });
    return next;
}
