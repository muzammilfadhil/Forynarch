import QtQuick
import Quickshell.Io
Item {
    id: model
    visible:false
    property var controller:null
    property var info: ({available:true,settings:{profile:"normal",timeout:6,enabled:true,critical:true,allow:[]},current:[],history:[],dnd:false})
    property string error: ""
    property bool loaded: false
    readonly property bool busy: operation.running
    property string payload: ""
    function refresh() {if(!read.running&&!operation.running)read.running=true;}
    function execute(action,value) {if(busy)return;error="";payload=JSON.stringify(value||{});operation.command=["forynarch-notifications",action];operation.running=true;}
    function setting(key,value) {let next=Object.assign({},info.settings);next[key]=value;execute("set",next);}
    function receive(text) {try{const next=JSON.parse(text);if(JSON.stringify(next)!==JSON.stringify(info))info=next;loaded=true;if(controller)controller.notificationsDnd=info.dnd;if(info.available&&error==="The notification service could not be reached.")error="";}catch(e){error="Notifications could not be read.";}}
    Component.onCompleted: refresh()
    Timer {interval:2500;running:true;repeat:true;onTriggered:model.refresh()}
    Process {id:read;command:["forynarch-notifications","status"]
        stdout:StdioCollector {onStreamFinished:model.receive(text)}
        stderr:StdioCollector {onStreamFinished:{if(text.trim())model.error="The notification service could not be reached.";}}
    }
    Process {id:operation;stdinEnabled:true;onStarted:{write(model.payload);stdinEnabled=false;}
        stdout:StdioCollector {onStreamFinished:model.receive(text)}
        stderr:StdioCollector {onStreamFinished:{try{model.error=JSON.parse(text).error;}catch(e){if(text.trim())model.error="The notification change was not applied.";}}}
        onExited:()=>{stdinEnabled=true;model.refresh();}
    }
}
