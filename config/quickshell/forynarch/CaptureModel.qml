import QtQuick
import Quickshell.Io
Item {
    id: model
    visible:false
    required property var controller
    property var preferences:({saveFiles:true,copyClipboard:true,directory:"",historyEnabled:false})
    property string error:""
    property bool loaded:false
    readonly property bool busy:read.running||write.running
    property string pendingScreenshot:""
    function refresh(){if(!busy)read.running=true;}
    function receive(text){try{preferences=JSON.parse(text);loaded=true;}catch(e){error="Capture settings could not be read.";}}
    function set(key,value){if(busy)return;error="";write.command=["forynarch-capture","set",key,String(value)];write.running=true;}
    function take(kind){controller.clearPopups();controller.requestFocusReturn();pendingScreenshot=kind;captureDelay.restart();}
    Component.onCompleted:refresh()
    Timer {id:captureDelay;interval:180;onTriggered:model.controller.run(["forynarch-capture",model.pendingScreenshot])}
    Process {id:read;command:["forynarch-capture","status"]
        stdout:StdioCollector{onStreamFinished:model.receive(text)}
        stderr:StdioCollector{onStreamFinished:if(text.trim())model.error="Capture settings could not be read."}
    }
    Process {id:write
        stdout:StdioCollector{onStreamFinished:model.receive(text)}
        stderr:StdioCollector{onStreamFinished:if(text.trim())model.error=text.trim()}
        onExited:()=>model.refresh()
    }
    Process {running:model.loaded&&model.preferences.historyEnabled
        command:["wl-paste","--type","text","--watch","forynarch-capture","clipboard-store","text/plain"]
    }
    Process {running:model.loaded&&model.preferences.historyEnabled
        command:["wl-paste","--type","image/png","--watch","forynarch-capture","clipboard-store","image/png"]
    }
}
