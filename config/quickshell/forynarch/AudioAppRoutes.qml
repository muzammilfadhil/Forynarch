import QtQuick
import QtQuick.Layouts
ColumnLayout {
    id:routes
    required property var controller
    property string applicationKey:""
    property var excludeKeys:[]
    readonly property var router:controller.audioRouter??null
    readonly property var applications:(router?.snapshot.apps??[]).filter(app=>applicationKey?app.key===applicationKey:!excludeKeys.includes(app.key))
    spacing:6
    Repeater {
        model:routes.applications
        ColumnLayout {
            id:application
            required property var modelData
            Layout.fillWidth:true;spacing:6
            Text {Layout.fillWidth:true;visible:routes.applicationKey==="";text:application.modelData.name;color:"#dfe9f8";font.pixelSize:13;textFormat:Text.PlainText;elide:Text.ElideRight}
            Repeater {
                model:["output","input"].filter(direction=>application.modelData[direction].length>0)
                RowLayout {
                    id:directionRow
                    required property string modelData
                    readonly property var streams:application.modelData[modelData]
                    readonly property string selected:streams.every(node=>node.target===streams[0].target)?(streams[0].target==="0"?"default":streams[0].target):"mixed"
                    Layout.fillWidth:true;spacing:8
                    Text {text:directionRow.modelData==="output"?"Output":"Input";Layout.preferredWidth:48;color:"#b5c9df";font.pixelSize:12}
                    Choice {
                        Layout.fillWidth:true;implicitHeight:36
                        choices:[{label:"System default",value:"default"},{label:"App settings",value:"app"}].concat((routes.router?.snapshot.devices[directionRow.modelData]??[]).map(device=>({label:device.name,value:device.serial}))).concat(directionRow.selected==="mixed"?[{label:"Different devices",value:"mixed"}]:[])
                        selectedValue:directionRow.selected;enabled:!routes.router?.busy
                        Accessible.name:application.modelData.name+" "+directionRow.modelData+" device"
                        onChosen:value=>{if(value!=="mixed")routes.router.choose(application.modelData,directionRow.modelData,String(value));}
                    }
                }
            }
        }
    }
    Text {Layout.fillWidth:true;visible:!!routes.router?.error;text:routes.router?.error??"";color:"#efc2b0";font.pixelSize:12;wrapMode:Text.WordWrap}
}
