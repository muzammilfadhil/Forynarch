import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

ColumnLayout {
    id: geometry
    required property var controller
    property var preferences: ({windowGap:6,screenMargin:14,cornerRadius:10})
    property var pending: ({})
    property var inFlight: null
    property string error: ""
    spacing:10
    function queue(key,value) {
        pending=Object.assign({},pending,{[key]:typeof value==="number"?Math.round(value):value});
        applyDelay.restart();
    }
    function applyNext() {
        if(action.running||readPreferences.running)return;
        const key=Object.keys(pending)[0];if(!key)return;
        const value=pending[key];const next=Object.assign({},pending);delete next[key];pending=next;
        inFlight={key:key,value:value};
        error="";action.command=["forynarch-system","set",key,String(value)];action.running=true;
    }
    Component.onDestruction: {
        const remaining=Object.assign({},inFlight?{[inFlight.key]:inFlight.value}:{},pending);
        Object.keys(remaining).forEach(key=>controller.run(["forynarch-system","set",key,String(remaining[key])]));
    }
    Timer {id:applyDelay;interval:180;onTriggered:geometry.applyNext()}
    Process {
        id:readPreferences;command:["forynarch-system","preferences"];running:true
        stdout:StdioCollector {onStreamFinished:{try{geometry.preferences=JSON.parse(text);}catch(e){geometry.error="Window settings could not be read.";}}}
        onExited:if(Object.keys(geometry.pending).length)applyDelay.restart()
    }
    Process {
        id:action
        stderr:StdioCollector {onStreamFinished:if(text.trim())geometry.error=text.trim()}
        onExited:(code,status)=>{inFlight=null;if(code!==0&&!geometry.error)geometry.error="Window settings could not be applied.";readPreferences.running=true;}
    }
    Repeater {
        model:[
            {key:"windowGap",title:"Window gap",detail:"Space per window edge; 0 removes empty gaps",maximum:40},
            {key:"screenMargin",title:"Screen margin",detail:"Space between tiles and the screen edges",maximum:64},
            {key:"cornerRadius",title:"Window corners",detail:"0 is square; higher values are more rounded",maximum:40}
        ]
        SettingRow {
            required property var modelData
            Layout.fillWidth:true;title:modelData.title;description:modelData.detail
            ThemedSlider {
                id:valueSlider
                from:0;to:modelData.maximum;stepSize:1
                value:geometry.preferences[modelData.key]??0
                accent:geometry.controller.accent
                Accessible.name:modelData.title
                onMoved:geometry.queue(modelData.key,value)
            }
            Text {width:40;anchors.verticalCenter:parent.verticalCenter;text:Math.round(valueSlider.value)+" px";color:"#deebfc";font.pixelSize:12;horizontalAlignment:Text.AlignRight}
        }
    }
    Text {text:"Focused window outline";color:"#deebfc";font.pixelSize:15;font.weight:Font.Medium}
    Repeater {
        model:[{key:"focusTiled",title:"Tiling layouts"},{key:"focusFloating",title:"Floating windows"}]
        SettingRow {
            required property var modelData
            Layout.fillWidth:true;title:modelData.title;description:"Highlight the focused window independently in this mode"
            Toggle {checked:geometry.pending[modelData.key]??geometry.preferences[modelData.key]??true;Accessible.name:modelData.title+" focus outline";onClicked:geometry.queue(modelData.key,checked)}
        }
    }
    RowLayout {
        Layout.fillWidth:true;spacing:8
        Text {text:"Outline color";color:"#deebfc";font.pixelSize:12;Layout.fillWidth:true}
        Repeater {
            model:["#96c8ff","#68d7e6","#b6a1ef","#8ed6b1","#eeeeee"]
            AbstractButton {
                required property string modelData
                implicitWidth:26;implicitHeight:26;Accessible.name:"Outline color "+modelData
                background:Rectangle {color:parent.modelData;radius:13;border.width:parent.activeFocus?3:1;border.color:parent.activeFocus?"white":"#57718d"}
                onClicked:geometry.queue("focusColor",modelData)
            }
        }
        TextField {
            Layout.preferredWidth:100;maximumLength:7;text:geometry.preferences.focusColor||"#96c8ff";color:"#deebfc"
            Accessible.name:"Custom outline color, hexadecimal"
            background:Rectangle {color:"#24374e";radius:7;border.width:parent.activeFocus?2:1;border.color:"#57718d"}
            onEditingFinished:{if(/^#[0-9a-fA-F]{6}$/.test(text))geometry.queue("focusColor",text);else text=geometry.preferences.focusColor;}
        }
    }
    Text {visible:geometry.error!=="";text:geometry.error;color:"#ffc2af";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
}
