import QtQuick
import Quickshell.Io
Item {
    id:router
    visible:false
    property bool active:false
    property var snapshot:({devices:{output:[],input:[]},apps:[]})
    property string error:""
    readonly property bool busy:operation.running
    function refresh(){if(active&&!read.running&&!operation.running)read.running=true;}
    function choose(app,direction,target){
        if(operation.running)return;
        error="";
        operation.payload=JSON.stringify({streams:app[direction].map(node=>({id:node.id,serial:node.serial})),direction:direction,target:target});
        operation.stdinEnabled=true;operation.running=true;
    }
    onActiveChanged:if(active)refresh()
    Timer {interval:1500;repeat:true;running:router.active;onTriggered:router.refresh()}
    Process {id:read;command:["forynarch-audio","status"]
        stdout:StdioCollector {onStreamFinished:{try{router.snapshot=JSON.parse(text);}catch(e){}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim())try{router.error=JSON.parse(text).error;}catch(e){router.error="Audio devices could not be read.";}}}
    }
    Process {id:operation;command:["forynarch-audio","route"];property string payload:""
        onStarted:{write(payload);stdinEnabled=false;}
        stdout:StdioCollector {onStreamFinished:{try{router.snapshot=JSON.parse(text);}catch(e){}}}
        stderr:StdioCollector {onStreamFinished:{if(text.trim())try{router.error=JSON.parse(text).error;}catch(e){router.error="The app's audio device could not be changed.";}}}
        onExited:router.refresh()
    }
}
