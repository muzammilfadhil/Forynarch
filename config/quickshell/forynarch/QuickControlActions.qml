import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import "WifiStatus.js" as WifiStatus

Item {
    id: actions
    required property var controller
    property var networkService:Networking
    visible:false
    readonly property var wifiAdapters:{
        const found=[];
        for(const device of networkService.devices.values)
            if(device.type===DeviceType.Wifi)found.push(device);
        return found;
    }
    readonly property var bluetoothAdapters:Bluetooth.adapters.values
    readonly property bool wifiAvailable:wifiAdapters.length>0
    readonly property bool wifiOn:networkService.wifiEnabled&&networkService.wifiHardwareEnabled
    property var wifiDeviceState:null
    property string wifiAccessPointText:""
    readonly property string activeWifiName:{
        for(const adapter of wifiAdapters)for(const network of adapter.networks.values)if(network.connected)return network.name;
        return "";
    }
    readonly property bool wifiConnected:{
        if(wifiDeviceState)return wifiDeviceState.connected;
        for(const adapter of wifiAdapters)if(adapter.connected)return true;
        return false;
    }
    readonly property string wifiName:!wifiOn?"Off":wifiConnected?(activeWifiName||WifiStatus.ssid(wifiAccessPointText,wifiDeviceState?.name||"")||wifiDeviceState?.connection||"Connected"):(wifiDeviceState?.connecting?"Connecting…":"Not Connected")
    readonly property bool bluetoothOn:bluetoothAdapters.some(d=>d.enabled)
    property var airplanePrevious:null
    readonly property bool airplane:airplanePrevious!==null&&!networkService.wifiEnabled&&!bluetoothOn
    readonly property bool keepAwake:inhibitor.running
    readonly property bool nightLight:night.running
    property bool canNightLight:false
    property bool backlight:false
    property real brightness:0
    property string error:""
    property int requestedBrightness:50

    function refresh(){if(!inspect.running)inspect.running=true;if(!systemInfo.running)systemInfo.running=true;refreshWifi();}
    function refreshWifi(){if(!wifiStatus.running)wifiStatus.running=true;if(!wifiAccessPoints.running)wifiAccessPoints.running=true;}
    function toggleWifi(){error="";networkService.wifiEnabled=!networkService.wifiEnabled;refreshWifi();}
    function toggleBluetooth(){error="";const on=!bluetoothOn;for(const adapter of bluetoothAdapters)adapter.enabled=on;}
    function toggleAirplane(){
        error="";
        if(airplane){
            networkService.wifiEnabled=airplanePrevious.wifi;
            for(const previous of airplanePrevious.bluetooth)if(bluetoothAdapters.includes(previous.adapter))previous.adapter.enabled=previous.enabled;
            airplanePrevious=null;
        }else{
            airplanePrevious={wifi:networkService.wifiEnabled,bluetooth:bluetoothAdapters.map(adapter=>({adapter:adapter,enabled:adapter.enabled}))};
            networkService.wifiEnabled=false;
            for(const adapter of bluetoothAdapters)adapter.enabled=false;
        }
    }
    function toggleDnd(){if(!focus.running){error="";focus.running=true;}}
    function toggleAwake(){error="";inhibitor.running=!inhibitor.running;}
    function toggleNightLight(){if(canNightLight){error="";night.running=!night.running;}}
    function setBrightness(value){if(!backlight)return;requestedBrightness=Math.max(1,Math.min(100,Math.round(value*100)));brightness=requestedBrightness;brightnessDelay.restart();}
    function failed(text){if(text.trim())error=text.trim().slice(0,300);}

    Timer{interval:2500;running:controller.controlOpen;repeat:true;onTriggered:actions.refreshWifi()}
    Process{
        id:wifiStatus
        command:["env","LC_ALL=C","nmcli","--terse","--escape","yes","--fields","DEVICE,TYPE,STATE,CONNECTION","device","status"]
        property string result:""
        stdout:StdioCollector{onStreamFinished:wifiStatus.result=text}
        onExited:(code)=>{actions.wifiDeviceState=code===0?WifiStatus.device(result):null;}
    }
    Process{
        id:wifiAccessPoints
        command:["env","LC_ALL=C","nmcli","--terse","--escape","yes","--fields","DEVICE,IN-USE,SSID","device","wifi","list","--rescan","no"]
        property string result:""
        stdout:StdioCollector{onStreamFinished:wifiAccessPoints.result=text}
        onExited:(code)=>{actions.wifiAccessPointText=code===0?result:"";}
    }

    Process {
        id:inspect
        command:["sh","-c","night=false;command -v hyprsunset >/dev/null && night=true;printf '{\"night\":%s}' \"$night\""]
        stdout:StdioCollector{onStreamFinished:{try{const tools=JSON.parse(text);actions.canNightLight=tools.night;}catch(e){}}}
    }
    Process {
        id:systemInfo;command:["forynarch-system","status"]
        stdout:StdioCollector{onStreamFinished:{try{const info=JSON.parse(text);actions.backlight=info.backlight;actions.brightness=info.brightness;}catch(e){}}}
    }
    Timer{id:brightnessDelay;interval:100;onTriggered:{if(brightnessCommand.running){restart();return;}brightnessCommand.command=["forynarch-system","brightness",String(actions.requestedBrightness)];brightnessCommand.running=true;}}
    Process{
        id:brightnessCommand
        stderr:StdioCollector{onStreamFinished:actions.failed(text)}
        onExited:(code)=>{if(code!==0)actions.refresh();}
    }
    Process{
        id:focus;command:["forynarch-notifications","toggle"]
        stdout:StdioCollector{onStreamFinished:{try{controller.notificationsDnd=JSON.parse(text).dnd;}catch(e){}}}
        stderr:StdioCollector{onStreamFinished:actions.failed(text)}
    }
    Process{id:inhibitor;command:["systemd-inhibit","--what=idle:sleep","--who=Forynarch","--why=Keep Awake enabled in Control Center","sleep","infinity"];stderr:StdioCollector{onStreamFinished:actions.failed(text)}}
    Process{id:night;command:["hyprsunset","-t","4500"];stderr:StdioCollector{onStreamFinished:actions.failed(text)}}
}
