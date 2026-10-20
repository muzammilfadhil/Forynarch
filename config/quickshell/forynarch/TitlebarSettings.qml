import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: settings
    required property var controller
    property var snapshot: ({preferences:{enabled:true,useDefaults:true,exclusions:[],inclusions:[]},defaults:[],apps:[]})
    property string error: ""
    property bool showDefaults: false
    readonly property bool busy: read.running || change.running
    readonly property var overrides: snapshot.preferences.exclusions.map(key=>({key:key,native:true})).concat(snapshot.preferences.inclusions.map(key=>({key:key,native:false})))
    spacing: 10

    function receive(text) {
        try {
            const result=JSON.parse(text);
            if(result.error) error=result.error;
            else if(result.preferences) snapshot=result;
        } catch(e) { error="Window control preferences could not be read."; }
    }
    function request(args) {
        if(busy)return;
        error="";
        change.command=["forynarch-titlebars"].concat(args);
        change.running=true;
    }
    Process {
        id: read
        command:["forynarch-titlebars","status"]; running:true
        stdout:StdioCollector {onStreamFinished:settings.receive(text)}
        onExited:(code,status)=>{if(code!==0&&!settings.error)settings.error="Window control preferences are unavailable.";}
    }
    Process {
        id: change
        stdout:StdioCollector {onStreamFinished:settings.receive(text)}
        onExited:(code,status)=>{if(code!==0&&!settings.error)settings.error="Window control preferences were not applied.";}
    }

    Text {text:"Window controls";color:"#deebfc";font.pixelSize:15;font.weight:Font.Medium}
    SettingRow {
        Layout.fillWidth:true; title:"Forynarch titlebars"
        description:"Add window controls to floating apps that need them. Tiled windows keep their existing layout."
        Toggle {checked:settings.snapshot.preferences.enabled;enabled:!settings.busy;accent:controller.accent;Accessible.name:"Forynarch titlebars";onClicked:settings.request(["set","enabled",String(checked)])}
    }
    SettingRow {
        Layout.fillWidth:true; title:"Keep app controls"
        description:"Skip the extra titlebar for common browsers, Discord, Steam, Mudil Music and headerbar apps."
        Toggle {checked:settings.snapshot.preferences.useDefaults;enabled:!settings.busy;accent:controller.accent;Accessible.name:"Use common app titlebar exceptions";onClicked:settings.request(["set","useDefaults",String(checked)])}
    }
    ActionButton {label:settings.showDefaults?"Hide common app exceptions":"View common app exceptions";quiet:true;showTooltip:false;onClicked:settings.showDefaults=!settings.showDefaults}
    Repeater {
        model:settings.showDefaults?settings.snapshot.defaults:[]
        Text {required property var modelData;Layout.fillWidth:true;text:modelData.name;textFormat:Text.PlainText;color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    }
    RowLayout {
        Layout.fillWidth:true
        Text {text:"Running apps";color:"#deebfc";font.pixelSize:14;Layout.fillWidth:true}
        ActionButton {label:"Refresh";showTooltip:false;enabled:!settings.busy;onClicked:{settings.error="";read.running=true;}}
    }
    Text {
        Layout.fillWidth:true;text:"Turn on App controls to remove the extra bar. Turn it off if the app has no controls of its own. Changes apply to open floating windows."
        color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap
    }
    Text {visible:settings.busy;text:"Updating window controls…";color:"#b5c9e3";font.pixelSize:12}
    Text {visible:!settings.busy&&!settings.snapshot.apps.length;text:"No application windows are open. Add an exact app class below or open an app and refresh.";Layout.fillWidth:true;color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    Repeater {
        model:settings.snapshot.apps
        SettingRow {
            id: appRow
            required property var modelData
            Layout.fillWidth:true;title:modelData.name
            description:modelData.class+(modelData.source==="custom"?" · Custom rule":"")
            Toggle {checked:appRow.modelData.native;enabled:!settings.busy&&settings.snapshot.preferences.enabled;accent:controller.accent;Accessible.name:"App controls for "+modelData.name;onClicked:settings.request(["except",modelData.class,String(checked)])}
        }
    }
    Text {text:"Custom rules";color:"#deebfc";font.pixelSize:14;Layout.topMargin:6}
    RowLayout {
        Layout.fillWidth:true;spacing:8
        TextField {
            id: appClass
            Layout.fillWidth:true;maximumLength:160;placeholderText:"Exact app class, for example obsidian"
            implicitHeight:40;padding:10;font.pixelSize:13;placeholderTextColor:"#a6bbd2"
            color:"#deebfc";selectByMouse:true;Accessible.name:"Application class to use its own controls"
            background:Rectangle {color:"#24374e";radius:7;border.width:appClass.activeFocus?2:1;border.color:appClass.activeFocus?"#e5efff":"#7896b7"}
            onAccepted:if(text.trim()&&!settings.busy)settings.request(["except",text.trim(),"true"])
        }
        ActionButton {label:"Add exception";showTooltip:false;enabled:!settings.busy&&appClass.text.trim()!=="";onClicked:settings.request(["except",appClass.text.trim(),"true"])}
    }
    Repeater {
        model:settings.overrides
        SettingRow {
            required property var modelData
            Layout.fillWidth:true;title:modelData.key
            description:modelData.native?"Use the app's own controls":"Use Forynarch controls when floating"
            ActionButton {label:"Remove";showTooltip:false;enabled:!settings.busy;Accessible.name:"Remove titlebar rule for "+modelData.key;onClicked:settings.request(["forget",modelData.key])}
        }
    }
    Text {visible:settings.error!=="";text:settings.error;textFormat:Text.PlainText;color:"#ffc2af";Layout.fillWidth:true;font.pixelSize:12;wrapMode:Text.WordWrap;Accessible.name:text}
}
