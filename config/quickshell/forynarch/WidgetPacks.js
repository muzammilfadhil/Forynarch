.pragma library
var widgets = [
    {id:"clock",label:"Analog clock"}, {id:"calendar",label:"This week"},
    {id:"greeting",label:"Greeting"}, {id:"media",label:"Music"},
    {id:"digital",label:"Digital clock"}, {id:"focus",label:"Focus timer"},
    {id:"system",label:"Memory"}, {id:"battery",label:"Battery"},
    {id:"launchpad",label:"Quick launch"}, {id:"shortcuts",label:"Keyboard guide"}
];
var packs = [
    {id:"essentials",label:"Essentials",description:"Time, calendar and music",keys:["clock","calendar","greeting","media"]},
    {id:"focus",label:"Focus",description:"A quiet work session",keys:["digital","focus","system","shortcuts"]},
    {id:"laptop",label:"Laptop",description:"Battery, time and quick actions",keys:["digital","battery","media","launchpad"]},
    {id:"minimal",label:"Minimal",description:"Only the time",keys:["digital"]}
];
function extras(value) {
    var result={};widgets.slice(4).forEach(row=>result[row.id]=value?.[row.id]===true);
    Object.keys(value||{}).filter(key=>/^custom:[a-z][a-z0-9-]{0,39}:[a-z][a-z0-9-]{0,39}$/.test(key)).slice(0,24).forEach(key=>result[key]=value[key]===true);
    return result;
}
