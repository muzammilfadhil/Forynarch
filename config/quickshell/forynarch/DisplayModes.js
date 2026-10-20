.pragma library
function modes(monitor) {
    return (monitor?.availableModes||[]).map(value=>{
        const match=/^(\d+)x(\d+)@([\d.]+)Hz$/.exec(value);
        return match?{value:value.slice(0,-2),resolution:match[1]+"x"+match[2],width:Number(match[1]),height:Number(match[2]),refresh:Number(match[3])}:null;
    }).filter(mode=>mode&&Number.isFinite(mode.refresh)&&mode.refresh>0);
}
function resolutions(monitor) {
    const unique=[];
    for(const mode of modes(monitor))if(!unique.some(row=>row.value===mode.resolution))unique.push({label:mode.width+" × "+mode.height,value:mode.resolution,area:mode.width*mode.height});
    return unique.sort((a,b)=>b.area-a.area);
}
function rates(monitor,resolution) {
    const unique=[];
    for(const mode of modes(monitor))if(mode.resolution===resolution&&!unique.some(row=>row.value===mode.value))unique.push({label:mode.refresh.toFixed(2)+" Hz",value:mode.value,refresh:mode.refresh});
    return unique.sort((a,b)=>b.refresh-a.refresh);
}
function nearest(monitor,resolution,refresh) {
    return rates(monitor,resolution).sort((a,b)=>Math.abs(a.refresh-refresh)-Math.abs(b.refresh-refresh))[0]?.value||"";
}
function current(monitor) {return monitor?nearest(monitor,monitor.width+"x"+monitor.height,monitor.refreshRate):"";}
function validScale(mode,scale) {
    const match=/^(\d+)x(\d+)@/.exec(mode);
    return !!match&&Number.isFinite(scale)&&scale>0&&Number(match[1])/scale%1===0&&Number(match[2])/scale%1===0;
}
