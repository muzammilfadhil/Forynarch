import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "PanelMetrics.js" as Metrics

ColumnLayout{
    required property var controller
    spacing:12
    Repeater{
        model:["Bar","Applications","Labels","Window previews"]
        ColumnLayout{
            id:group;required property string modelData
            Layout.fillWidth:true;spacing:8
            Text{text:group.modelData;color:"#deebfc";font.pixelSize:15;font.weight:Font.Medium;Layout.topMargin:8}
            Repeater{
                model:Metrics.fields.filter(field=>field.group===group.modelData)
                RowLayout{
                    required property var modelData
                    Layout.fillWidth:true;spacing:12
                    Text{Layout.fillWidth:true;text:modelData.label;color:"#deebfc";font.pixelSize:12;wrapMode:Text.WordWrap}
                    SpinBox{
                        Layout.preferredWidth:112;implicitHeight:34
                        from:modelData.min;to:modelData.max;value:controller.panelMetrics[modelData.key];editable:true
                        Accessible.name:modelData.label+" in pixels"
                        palette.text:"#deebfc";palette.base:"#24374e";palette.button:"#30465f";palette.buttonText:"#deebfc"
                        font.pixelSize:12
                        onValueModified:controller.setPanelMetric(modelData.key,value)
                    }
                }
            }
        }
    }
    Text{Layout.fillWidth:true;text:"Values are in pixels. Offsets stay within the bar. Increase its height for more room; larger labels can expand it automatically.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap}
    ActionButton{label:"Reset navigation sizing";onClicked:controller.resetPanelMetrics()}
}
