import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id:view
    required property var controller
    property var cards:[]
    property string error:""
    property string serviceMessage:""
    readonly property string message:error||serviceMessage
    readonly property bool busy:operation.running
    spacing:10
    function refresh(){if(!read.running&&!busy)read.running=true;}
    function choose(card,profile){if(busy)return;error="";operation.payload=JSON.stringify({card:card.name,profile:profile});operation.running=true;}
    Component.onCompleted:refresh()
    Timer{interval:2000;repeat:true;running:view.visible;onTriggered:view.refresh()}
    Process{
        id:read;command:["forynarch-audio-hardware","status"]
        stdout:StdioCollector{onStreamFinished:{try{const result=JSON.parse(text);view.cards=result.cards;view.serviceMessage=result.message||"";}catch(e){view.serviceMessage="Audio hardware could not be read.";}}}
    }
    Process{
        id:operation;command:["forynarch-audio-hardware","set-profile"];stdinEnabled:true;property string payload:""
        onStarted:{write(payload);stdinEnabled=false;}
        onExited:{stdinEnabled=true;view.refresh();}
        stderr:StdioCollector{onStreamFinished:{try{view.error=JSON.parse(text).error;}catch(e){view.error="The audio profile could not be changed.";}}}
    }
    Text{text:"Audio hardware";color:"#e1edff";font.pixelSize:15;font.weight:Font.DemiBold}
    Text{Layout.fillWidth:true;text:"Enable a device or choose its profile. Off disables all inputs and outputs on that device.";wrapMode:Text.WordWrap;color:"#a3bad4";font.pixelSize:12}
    Text{Layout.fillWidth:true;visible:view.message!=="";text:view.message;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#f2c5aa";font.pixelSize:12}
    Repeater{
        model:view.cards
        ColumnLayout{
            required property var modelData
            Layout.fillWidth:true;spacing:8
            RowLayout{
                Layout.fillWidth:true
                Text{Layout.fillWidth:true;text:modelData.description;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#dfe9f8";font.pixelSize:13}
                Toggle{checked:modelData.enabled;enabled:!view.busy;accent:controller.accent;Accessible.name:"Enable "+modelData.description;onClicked:view.choose(modelData,checked?"restore":"off")}
            }
            Choice{Layout.fillWidth:true;choices:modelData.profiles.filter(p=>p.available||p.name===modelData.active).map(p=>({label:p.label,value:p.name}));selectedValue:modelData.active;enabled:!view.busy;Accessible.name:modelData.description+" profile";onChosen:value=>view.choose(modelData,value)}
        }
    }
}
