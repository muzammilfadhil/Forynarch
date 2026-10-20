import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "DisplayModes.js" as DisplayModes

ColumnLayout {
    id:system
    required property var controller
    required property string pageTitle
    property alias displayConfirmation:displayConfirmation
    property var info:({preferences:{},monitors:[],network:[],audio:[],batteries:[],wifi:false,networkManager:false,bluetooth:false,live:true,backlight:false,brightness:0,displayPreview:{preview:false}})
    property string message:""
    property bool failed:false
    property string operationOutput:""
    property string operationError:""
    readonly property bool busy:scan.running||action.running
    readonly property var prefs:info.preferences||{}
    property string selectedDisplay:""
    readonly property var monitor:info.monitors.find(m=>m.name===selectedDisplay)||info.monitors[0]||null
    property string mode:""
    property real displayScale:1
    property int rotation:0
    property string position:"auto"
    property int remaining:0
    spacing:12
    function refresh(){if(!busy)scan.running=true;}
    function execute(command){if(busy)return;message="";operationOutput="";operationError="";failed=false;action.command=command;action.running=true;}
    function set(key,value){execute(["forynarch-system","set",key,String(value)]);}
    function preset(values){return values.map(v=>({label:v===0?"Never":(v/60)+" minutes",value:v}));}
    onPageTitleChanged:refresh()
    onMonitorChanged:{if(monitor){mode=DisplayModes.current(monitor);displayScale=monitor.scale;rotation=monitor.transform||0;position=monitor.x+"x"+monitor.y;}}
    Component.onCompleted:refresh()
    Process {
        id:scan;command:["forynarch-system","status"]
        stdout:StdioCollector {onStreamFinished:{try{system.info=JSON.parse(text);if(system.info.displayPreview?.preview){system.remaining=Math.max(0,Math.ceil((Number(system.info.displayPreview.deadline)-Date.now())/1000));countdown.restart();}}catch(e){system.message="System information could not be read.";system.failed=true;}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim()){system.message=text.trim();system.failed=true;}}}
    }
    Process {
        id:action
        stdout:StdioCollector {onStreamFinished:system.operationOutput=text.trim()}
        stderr:StdioCollector {onStreamFinished:system.operationError=text.trim()}
        onExited:(code,status)=>{system.failed=code!==0;system.message=system.failed?(system.operationError||system.operationOutput||"The change could not be applied."):"";scan.running=true;}
    }
    Timer {id:countdown;interval:1000;repeat:true;onTriggered:{system.remaining=Math.max(0,Math.ceil((Number(system.info.displayPreview.deadline)-Date.now())/1000));if(remaining===0){stop();system.refresh();}}}
    Dialog {
        id:displayConfirmation
        objectName:"displayConfirmation"
        parent:Overlay.overlay
        anchors.centerIn:parent
        width:Math.min(440,(parent?.width||480)-32)
        padding:24;modal:true;focus:true
        visible:system.info.displayPreview?.preview||false
        closePolicy:Popup.CloseOnEscape
        onOpened:displayKeep.forceActiveFocus()
        onRejected:system.execute(["forynarch-display","revert"])
        background:Rectangle{radius:16;color:"#14263b";border.color:"#6483a3"}
        contentItem:ColumnLayout{
            spacing:16
            Text{Layout.fillWidth:true;text:"Keep these display settings?";wrapMode:Text.WordWrap;color:"#e2eeff";font.pixelSize:19;font.weight:Font.DemiBold}
            Text{Layout.fillWidth:true;text:"Reverting in "+system.remaining+" seconds. If the picture is unreadable, wait for the previous settings to return.";wrapMode:Text.WordWrap;color:"#b5cbe3";font.pixelSize:13}
            RowLayout{
                Layout.fillWidth:true
                ActionButton{label:"Revert";enabled:!system.busy;onClicked:system.execute(["forynarch-display","revert"])}
                Item{Layout.fillWidth:true}
                ActionButton{id:displayKeep;objectName:"keepDisplay";label:"Keep changes";selected:true;accent:controller.accent;enabled:!system.busy;onClicked:system.execute(["forynarch-display","keep"])}
            }
        }
    }
    RowLayout {
        visible:system.pageTitle!=="Storage"
        Layout.fillWidth:true
        Text {text:system.busy?"Reading system state…":"Changes apply only when selected";color:"#8fa7c4";font.pixelSize:11;Layout.fillWidth:true;wrapMode:Text.WordWrap}
        ActionButton {animateHover:controller.motion;label:"Refresh";enabled:!system.busy;onClicked:system.refresh()}
        ActionButton {objectName:"previewDisplay";visible:system.pageTitle==="Displays";animateHover:controller.motion;label:"Preview changes";enabled:!system.busy&&!!system.monitor&&system.mode!==""&&!system.info.displayPreview?.preview;onClicked:system.execute(["forynarch-display","preview",system.monitor.name,system.mode,String(system.displayScale),system.position,String(system.rotation)])}
    }
    Loader {
        Layout.fillWidth:true;Layout.preferredHeight:item?item.implicitHeight:0
        sourceComponent:system.pageTitle==="Network"?networkPage:system.pageTitle==="Bluetooth"?bluetoothPage:system.pageTitle==="Sound"?soundPage:system.pageTitle==="Displays"?displaysPage:system.pageTitle==="Power"?powerPage:system.pageTitle==="Input"?inputPage:system.pageTitle==="Storage"?storagePage:system.pageTitle==="About"?aboutPage:privacyPage
    }
    Text {Layout.fillWidth:true;visible:system.message!=="";text:system.message;wrapMode:Text.WordWrap;maximumLineCount:5;elide:Text.ElideRight;color:system.failed?"#f1b8a8":"#b5d5f8";font.pixelSize:11}
    Component {
        id:networkPage
        NetworkPage {controller:system.controller;managerAvailable:system.info.networkManager===true}
    }
    Component {
        id:bluetoothPage
        BluetoothPage {controller:system.controller;pairingAvailable:system.info.bluetoothPairing===true}
    }
    Component {
        id:soundPage
        AudioPage {controller:system.controller}
    }
    Component {
        id:displaysPage
        ColumnLayout {spacing:10
            SettingRow {Layout.fillWidth:true;title:"Monitor";description:system.monitor?"Current refresh: "+system.monitor.refreshRate.toFixed(2)+" Hz":"No monitor detected"
                Choice {choices:system.info.monitors.map(m=>({label:m.name,value:m.name}));selectedValue:system.monitor?.name;onChosen:v=>system.selectedDisplay=v}
            }
            SettingRow {Layout.fillWidth:true;title:"Resolution";description:"Only resolutions reported by this monitor"
                Choice {objectName:"displayResolution";implicitWidth:220;choices:DisplayModes.resolutions(system.monitor);selectedValue:system.mode.split("@")[0];Accessible.name:"Display resolution";onChosen:v=>{system.mode=DisplayModes.nearest(system.monitor,v,Number(system.mode.split("@")[1])||system.monitor.refreshRate);if(!DisplayModes.validScale(system.mode,system.displayScale))system.displayScale=1;}}
            }
            SettingRow {Layout.fillWidth:true;title:"Refresh rate";description:"Rates available at the selected resolution"
                Choice {objectName:"displayRefresh";implicitWidth:220;choices:DisplayModes.rates(system.monitor,system.mode.split("@")[0]);selectedValue:system.mode;Accessible.name:"Display refresh rate";onChosen:v=>system.mode=v}
            }
            SettingRow {Layout.fillWidth:true;title:"Scale";description:"Interface size on this monitor"
                Choice {choices:[1,1.25,1.5,1.75,2].filter(v=>DisplayModes.validScale(system.mode,v)).map(v=>({label:(v*100)+"%",value:v}));selectedValue:system.displayScale;onChosen:v=>system.displayScale=v}
            }
            SettingRow {Layout.fillWidth:true;title:"Rotation";description:"Landscape or portrait"
                Choice {choices:[{label:"Landscape",value:0},{label:"Portrait",value:1},{label:"Inverted",value:2},{label:"Portrait, inverted",value:3}];selectedValue:system.rotation;onChosen:v=>system.rotation=v}
            }
            SettingRow {Layout.fillWidth:true;title:"Position";description:"Logical X/Y coordinates or automatic placement"
                TextField {implicitWidth:160;implicitHeight:38;leftPadding:12;rightPadding:12;text:system.position;placeholderText:"auto or 1920x0";placeholderTextColor:"#91a8c3";onTextEdited:system.position=text;color:"#dceaff";background:Rectangle {radius:10;color:"#24374e";border.width:1;border.color:"#38506c"}}
            }
            RowLayout {Layout.fillWidth:true
                Text {text:system.info.displayPreview?.preview?"Confirm within "+system.remaining+" seconds":"Display changes preview for 15 seconds";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#9eb8d5";font.pixelSize:12}
            }
            SettingRow {Layout.fillWidth:true;title:"Adaptive sync";description:"Fullscreen preference · Requires compatible hardware"
                Toggle {checked:system.prefs.vrr===2;enabled:!system.busy;accent:controller.accent;onClicked:system.set("vrr",checked?2:0)}
            }
            SettingRow {Layout.fillWidth:true;title:"Render only when needed";description:"Reduce idle GPU work with variable frame rate"
                Toggle {checked:system.prefs.vfr!==false;enabled:!system.busy;accent:controller.accent;onClicked:system.set("vfr",checked)}
            }
            SettingRow {Layout.fillWidth:true;title:"FPS diagnostics";description:"Compositor overlay · Monitor Hz is not game FPS"
                Toggle {checked:system.prefs.fpsOverlay||false;enabled:!system.busy;accent:controller.accent;onClicked:system.set("fpsOverlay",checked)}
            }
        }
    }
    Component {
        id:powerPage
        ColumnLayout {spacing:10
            BatteryDetails {Layout.fillWidth:true;controller:system.controller}
SettingRow {Layout.fillWidth:true;title:"Brightness";description:system.info.backlight?"Built-in display backlight":"No adjustable backlight detected"
                Choice {choices:[system.info.brightness||0,10,25,50,75,100].filter((v,i,a)=>a.indexOf(v)===i).sort((a,b)=>a-b).map(v=>({label:v+"%",value:v}));selectedValue:system.info.brightness||0;enabled:system.info.backlight===true&&!system.busy;onChosen:v=>system.execute(["forynarch-system","brightness",String(v)])}
            }
            SettingRow {Layout.fillWidth:true;title:"Lock after inactivity";description:system.info.live?"Unavailable for the passwordless Live user":"Requires your installed account password"
                Choice {choices:system.preset([0,300,600,900]);selectedValue:system.prefs.idleLock||0;enabled:!system.info.live&&!system.busy;onChosen:v=>system.set("idleLock",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Turn screen off";description:"Respects application idle inhibitors"
                Choice {choices:system.preset([0,300,600,900,1800]);selectedValue:system.prefs.idleBlank||0;enabled:!system.busy;onChosen:v=>system.set("idleBlank",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Automatic sleep";description:"Choose a delay longer than screen-off"
                Choice {choices:system.preset([0,900,1800,3600]);selectedValue:system.prefs.idleSleep||0;enabled:!system.busy;onChosen:v=>system.set("idleSleep",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Sleep and session actions";description:"Confirm before suspend, restart or shutdown"
                ActionButton {animateHover:controller.motion;label:"Open menu";onClicked:{controller.dismissSettings();controller.run(["forynarch-power"]);}}
            }
            Text {text:"Hibernation and CPU power profiles depend on installed services and hardware. This panel does not configure swap or change firmware.";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#91a8c3";font.pixelSize:12}
        }
    }
    Component {
        id:inputPage
        ColumnLayout {spacing:10
            SettingRow {Layout.fillWidth:true;title:"Keyboard layout";description:"Interface language stays English"
            Choice {choices:[{label:"English (US)",value:"us"},{label:"English (UK)",value:"gb"},{label:"German",value:"de"},{label:"French",value:"fr"},{label:"Spanish",value:"es"},{label:"Portuguese (Brazil)",value:"br"},{label:"Japanese",value:"jp"},{label:"Indonesian",value:"id"}];selectedValue:system.prefs.keyboardLayout||"us";enabled:!system.busy;onChosen:v=>system.set("keyboardLayout",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Key repeat rate";description:"Repeats per second"
                Choice {choices:[25,35,50,70].map(v=>({label:String(v),value:v}));selectedValue:system.prefs.repeatRate||25;enabled:!system.busy;onChosen:v=>system.set("repeatRate",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Repeat delay";description:"Delay before a held key repeats"
                Choice {choices:[250,400,600,800].map(v=>({label:v+" ms",value:v}));selectedValue:system.prefs.repeatDelay||600;enabled:!system.busy;onChosen:v=>system.set("repeatDelay",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Pointer speed";description:"Mouse sensitivity"
                Choice {choices:[{label:"Slowest",value:-1},{label:"Slow",value:-0.5},{label:"Balanced",value:0},{label:"Fast",value:0.5},{label:"Fastest",value:1}];selectedValue:system.prefs.sensitivity||0;enabled:!system.busy;onChosen:v=>system.set("sensitivity",v)}
            }
            SettingRow {Layout.fillWidth:true;title:"Natural touchpad scrolling";description:"Move content with your fingers"
                Toggle {checked:system.prefs.naturalScroll||false;enabled:!system.busy;accent:controller.accent;onClicked:system.set("naturalScroll",checked)}
            }
        }
    }
    Component {id:storagePage
        StoragePage {controller:system.controller}
    }
    Component {id:aboutPage
        ColumnLayout {spacing:10
SettingRow {Layout.fillWidth:true;title:"Operating system";description:"Forynarch"}
SettingRow {Layout.fillWidth:true;title:"Desktop";description:"Arch Linux · Hyprland · Blue Hour"}
            SettingRow {Layout.fillWidth:true;title:"Creator";description:"Muhammad Muzammil Fadhil"}
            SettingRow {Layout.fillWidth:true;title:"Session";description:system.info.live?"Live session":"Installed desktop"}
            SettingRow {Layout.fillWidth:true;visible:system.info.live;title:"Live image in RAM";description:system.info.liveImageCopiedToRam?"Yes. The copied system image uses RAM in addition to the desktop.":"No. The system image is read from the boot medium."}
            SettingRow {Layout.fillWidth:true;title:"Kernel";description:system.info.kernel||"Loading"}
            SettingRow {Layout.fillWidth:true;title:"Processor";description:system.info.processor||"Loading"}
            SettingRow {Layout.fillWidth:true;title:"Memory";description:system.info.memory?((system.info.memory.used/1000000000).toFixed(2)+" GB used / "+(system.info.memory.total/1000000000).toFixed(2)+" GB total") : "Loading"}
            Text {Layout.fillWidth:true;text:"Available memory is excluded from the used total. Choose Refresh to take a new reading.";wrapMode:Text.WordWrap;color:"#91a8c3";font.pixelSize:12}
        }
    }
    Component {id:privacyPage
        ColumnLayout {spacing:10
            SettingRow {Layout.fillWidth:true;title:"Do Not Disturb";description:"Silence notifications · Super+Ctrl+,"
                Toggle {checked:system.info.dnd===true;enabled:system.info.notifications===true&&!system.busy;accent:controller.accent;onClicked:system.execute(["forynarch-system","notifications",checked?"on":"off"])}
            }
            SettingRow {Layout.fillWidth:true;title:"Screen capture";description:"Capture only the region you choose"
                ActionButton {animateHover:controller.motion;label:"Screenshot";onClicked:{controller.dismissSettings();controller.run(["forynarch-hotkey","screenshot"]);}}
            }
            Text {Layout.fillWidth:true;text:"Screen sharing stays permission-gated through desktop portals. Camera and per-app microphone permission controls need application support; muting the microphone is available in Sound.";wrapMode:Text.WordWrap;color:"#91a8c3";font.pixelSize:12}
        }
    }
}
