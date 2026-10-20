import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
ColumnLayout {
    id: page
    required property var controller
    readonly property var model:controller.captureModel
    spacing:12
    Text {text:"Take a screenshot";color:"#deebfc";font.pixelSize:16;font.weight:Font.DemiBold}
    RowLayout {
        ActionButton {label:"Entire screen";icon:"displays";hint:"Print Screen";onClicked:page.model.take("fullscreen")}
        ActionButton {label:"Select an area";icon:"crop";hint:"Super + Shift + S";onClicked:page.model.take("region")}
    }
    Text {Layout.fillWidth:true;text:"Print Screen captures the entire desktop. For an area, drag to select and press Esc to cancel.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    SettingRow {Layout.fillWidth:true;title:"Save screenshots as files";description:"Keep a PNG in your screenshot folder"
        Toggle {checked:page.model.preferences.saveFiles;enabled:page.model.loaded&&!page.model.busy;Accessible.name:"Save screenshots as files";onClicked:page.model.set("saveFiles",checked)}
    }
    SettingRow {Layout.fillWidth:true;title:"Copy screenshots to clipboard";description:"Paste into messages, documents or an image editor"
        Toggle {checked:page.model.preferences.copyClipboard;enabled:page.model.loaded&&!page.model.busy;Accessible.name:"Copy screenshots to clipboard";onClicked:page.model.set("copyClipboard",checked)}
    }
    Text {Layout.fillWidth:true;text:"Keep at least one destination enabled. Turn file saving off for clipboard-only screenshots.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    SettingRow {Layout.fillWidth:true;title:"Screenshot folder";description:page.model.preferences.directory||"Pictures/Screenshots"
        ActionButton {label:"Choose…";icon:"folder";enabled:page.model.loaded&&!page.model.busy;onClicked:folder.open()}
    }
    FolderDialog {id:folder;title:"Choose screenshot folder";onAccepted:page.model.set("directory",decodeURIComponent(String(selectedFolder).replace(/^file:\/\//,"")))}
    SettingRow {Layout.fillWidth:true;title:"Clipboard history";description:"Remember copied text and PNG images on this device"
        Toggle {checked:page.model.preferences.historyEnabled;enabled:page.model.loaded&&!page.model.busy;Accessible.name:"Enable clipboard history";onClicked:page.model.set("historyEnabled",checked)}
    }
    Text {Layout.fillWidth:true;text:"History is optional and local: up to 50 entries and 16 MiB total. Password hints are skipped when the copying app supplies them.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    ActionButton {label:"Open clipboard history";icon:"clipboard";hint:"Super + Ctrl + V";onClicked:controller.openClipboard()}
    Text {Layout.fillWidth:true;visible:page.model.error!=="";text:page.model.error;color:"#ffc2af";wrapMode:Text.WordWrap}
}
