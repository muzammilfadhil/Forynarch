import QtQuick
import QtQuick.Layouts
import Quickshell.Io
ColumnLayout {
    id:page
    required property var controller
    property var values:({})
    property string error:""
    readonly property bool busy:action.running
    function set(key,value){if(action.running)return;error="";action.command=["forynarch-file-preferences","set",key,value];action.running=true;}
    Component.onCompleted:read.running=true
    Process {id:read;command:["forynarch-file-preferences","status"];stdout:StdioCollector {onStreamFinished:{try{page.values=JSON.parse(text);}catch(e){page.error="File preferences could not be read.";}}}}
    Process {
        id:action
        stderr:StdioCollector {onStreamFinished:page.error=text.trim()}
        onExited:(code,status)=>{if(code!==0&&!page.error)page.error="The change could not be saved.";read.running=true;}
    }
    spacing:12
    Text {text:"File Manager";color:"#e5efff";font.pixelSize:22;font.bold:true}
    Text {text:"Choose how your folders open and appear.";color:"#b5c9e3";wrapMode:Text.WordWrap;Layout.fillWidth:true}
    Repeater {
        model:[{key:"misc-single-click",title:"Open with one click",detail:"Turn off to open files with a double click"},{key:"misc-folders-first",title:"Folders first",detail:"List folders before files"},{key:"misc-show-hidden",title:"Show hidden files",detail:"Show names starting with a dot"},{key:"misc-confirm-close-multiple-tabs",title:"Confirm closing multiple tabs",detail:"Ask before closing a window with several tabs"},{key:"misc-use-csd",title:"Window controls",detail:"Show close, minimize and maximize controls. Reopen File Manager to apply."}]
        SettingRow {required property var modelData;Layout.fillWidth:true;title:modelData.title;description:modelData.detail
            Toggle {checked:page.values[modelData.key]==="true";enabled:!page.busy;Accessible.name:modelData.title;onClicked:page.set(modelData.key,String(checked))}
        }
    }
    SettingRow {Layout.fillWidth:true;title:"Folder view";description:"Default layout for folders"
        Choice {implicitHeight:44;choices:[{label:"Icons",value:"ThunarIconView"},{label:"Details",value:"ThunarDetailsView"},{label:"Compact",value:"ThunarCompactView"}];selectedValue:page.values["last-view"];onChosen:value=>page.set("last-view",value)}
    }
    SettingRow {Layout.fillWidth:true;title:"Thumbnails";description:"Remote thumbnails may use more data"
        Choice {implicitHeight:44;choices:[{label:"Local files",value:"THUNAR_THUMBNAIL_MODE_ONLY_LOCAL"},{label:"Never",value:"THUNAR_THUMBNAIL_MODE_NEVER"},{label:"All files",value:"THUNAR_THUMBNAIL_MODE_ALWAYS"}];selectedValue:page.values["misc-thumbnail-mode"];onChosen:value=>page.set("misc-thumbnail-mode",value)}
    }
    RowLayout {ActionButton {label:"Open File Manager";implicitHeight:44;onClicked:controller.run(["forynarch-files"])} ActionButton {label:"Advanced preferences";implicitHeight:44;onClicked:controller.run(["forynarch-file-preferences","advanced"])}}
    Text {visible:page.error!=="";text:page.error;color:"#ffc2af";wrapMode:Text.WordWrap;Layout.fillWidth:true}
}
