.pragma library

var fields=[
    {key:"barHeight",label:"Forynarch bar height",min:32,max:72,value:44,group:"Bar"},
    {key:"macBarHeight",label:"MacShell bar height",min:24,max:64,value:32,group:"Bar"},
    {key:"topMargin",label:"Distance from screen edge",min:0,max:24,value:8,group:"Bar"},
    {key:"groupPadding",label:"Group padding",min:4,max:24,value:8,group:"Bar"},
    {key:"groupSpacing",label:"Left group spacing",min:0,max:20,value:6,group:"Bar"},
    {key:"appSize",label:"Application button size",min:24,max:40,value:32,group:"Applications"},
    {key:"appIconSize",label:"Application icon size",min:16,max:32,value:22,group:"Applications"},
    {key:"appSpacing",label:"Space between applications",min:0,max:16,value:2,group:"Applications"},
    {key:"appOffsetY",label:"Application vertical offset",min:-12,max:12,value:0,group:"Applications"},
    {key:"indicatorGap",label:"Space below application icon",min:0,max:8,value:2,group:"Applications"},
    {key:"modeTextSize",label:"Desktop label size",min:8,max:16,value:10,group:"Labels"},
    {key:"workspaceTextSize",label:"Workspace label size",min:10,max:20,value:13,group:"Labels"},
    {key:"textOffsetY",label:"Label vertical offset",min:-8,max:8,value:0,group:"Labels"},
    {key:"previewWidth",label:"Preview card width",min:180,max:360,value:224,group:"Window previews"},
    {key:"previewTitleSize",label:"Window title size",min:10,max:20,value:12,group:"Window previews"},
    {key:"previewHeadingSize",label:"Application heading size",min:10,max:22,value:13,group:"Window previews"},
    {key:"previewTopGap",label:"Distance from bar",min:0,max:32,value:8,group:"Window previews"},
    {key:"previewPadding",label:"Preview padding",min:4,max:24,value:12,group:"Window previews"},
    {key:"previewGap",label:"Space between previews",min:0,max:20,value:8,group:"Window previews"},
    {key:"previewButtonSize",label:"Window control size",min:22,max:36,value:24,group:"Window previews"}
];
function defaults(){const result={};for(const field of fields)result[field.key]=field.value;return result;}
function valid(value){
    const result=defaults();
    if(!value||typeof value!=="object"||Array.isArray(value))return result;
    for(const field of fields)if(typeof value[field.key]==="number"&&Number.isFinite(value[field.key]))result[field.key]=Math.max(field.min,Math.min(field.max,Math.round(value[field.key])));
    return result;
}
function update(current,key,value){
    const field=fields.find(field=>field.key===key);
    if(!field||typeof value!=="number"||!Number.isFinite(value)||value<field.min||value>field.max)return null;
    const next=valid(current);next[key]=Math.round(value);return next;
}
