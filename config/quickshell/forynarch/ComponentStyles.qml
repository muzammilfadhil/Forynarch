import QtQuick
import QtQuick.Layouts

ColumnLayout {
    required property var controller
    spacing:12
    Text{text:"Desktop components";color:"#deebfc";font.pixelSize:15;font.weight:Font.Medium}
    Repeater {
        model:[{key:"panelStyle",label:"Bar style",detail:"Appearance of the main panel"},
               {key:"controlCenterStyle",label:"Control Center style",detail:"Independent of the bar and music widget"}]
        SettingRow {
            required property var modelData
            Layout.fillWidth:true;title:modelData.label;description:modelData.detail
            Choice {
                choices:[{label:"Forynarch",value:"classic"},{label:"MacShell",value:"macshell"}]
                selectedValue:controller[modelData.key]
                Accessible.name:modelData.label
                onChosen:value=>controller.setComponentStyle(modelData.key,value)
            }
        }
    }
    SettingRow {
        visible:controller.controlCenterStyle==="macshell";Layout.fillWidth:true
        title:"MacShell surface";description:"Original floating glass tiles or a single frosted panel"
        Choice {
            choices:[{label:"Glass tiles",value:"tiles"},{label:"Frosted panel",value:"panel"}]
            selectedValue:controller.controlCenterSurface
            Accessible.name:"MacShell surface"
            onChosen:value=>controller.setControlCenterSurface(value)
        }
    }
    Text{Layout.fillWidth:true;text:"Music cards have their own style in Desktop settings.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
}
