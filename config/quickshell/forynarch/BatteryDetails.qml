import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: details
    required property var controller
    readonly property var telemetry: controller.batteryStatus
    spacing: 12
    function formatted(value, suffix, decimals) { return value === null || value === undefined ? "Not reported" : Number(value).toFixed(decimals) + suffix; }
    function duration(seconds) {
        if (seconds === null || seconds === undefined) return "Not reported";
        const minutes = Math.max(1, Math.round(seconds / 60));
        return (minutes >= 60 ? Math.floor(minutes / 60) + " hr " : "") + (minutes % 60) + " min";
    }
    Text { Layout.fillWidth:true; visible:controller.batteryError.length>0; text:controller.batteryError; color:"#f0bd91"; font.pixelSize:12; wrapMode:Text.WordWrap }
    Text { Layout.fillWidth:true; visible:details.telemetry.batteries.length===0; text:"No system battery detected."; color:"#b5c9e3"; font.pixelSize:13; wrapMode:Text.WordWrap }
    Repeater {
        model: details.telemetry.batteries
        ColumnLayout {
            required property var modelData
            Layout.fillWidth:true; spacing:8
            RowLayout {
                Layout.fillWidth:true
                Text { Layout.fillWidth:true; text:modelData.name+"  "+details.formatted(modelData.capacity,"%",0); color:"#deebfc"; font.pixelSize:16; font.weight:Font.Medium; elide:Text.ElideRight }
                Text { text:modelData.status; color:controller.accent; font.pixelSize:13 }
            }
            Text {
                Layout.fillWidth:true
                text:details.formatted(modelData.watts," W",1)
                color:"#deebfc"; font.pixelSize:32; font.weight:Font.Medium
                Accessible.name:(modelData.status==="Charging"?"Battery charging power":modelData.status==="Discharging"?"Battery discharge power":"Battery power")+": "+text
            }
            Text { Layout.fillWidth:true; text:modelData.status==="Charging"?"Net power entering the battery":modelData.status==="Discharging"?"Power drawn from the battery":"Current battery power"; color:"#b5c9e3"; font.pixelSize:12; wrapMode:Text.WordWrap }
            Repeater {
                model:[
                    {label:modelData.status==="Charging"?"Until full":"Time remaining",value:details.duration(modelData.seconds)+(modelData.timeEstimated?" (estimated)":"")},
                    {label:"Stored energy",value:details.formatted(modelData.energyWh," Wh",1)},
                    {label:"Full capacity",value:details.formatted(modelData.fullWh," Wh",1)},
                    {label:"Battery health",value:details.formatted(modelData.health,"% of design",0)},
                    {label:"Temperature",value:details.formatted(modelData.temperatureC," \u00b0C",1)},
                    {label:"Charge cycles",value:details.formatted(modelData.cycles,"",0)}
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth:true; spacing:16
                    Text { Layout.fillWidth:true; text:modelData.label; color:"#b5c9e3"; font.pixelSize:12; wrapMode:Text.WordWrap }
                    Text { text:modelData.value; color:"#deebfc"; font.pixelSize:12 }
                }
            }
            Rectangle { Layout.fillWidth:true; implicitHeight:1; color:"#354b63"; Layout.topMargin:6 }
        }
    }
    Repeater {
        model: details.telemetry.adapters
        RowLayout {
            required property var modelData
            Layout.fillWidth:true; spacing:12
            Text { Layout.fillWidth:true; text:modelData.name+" \u00b7 "+modelData.type; color:"#b5c9e3"; font.pixelSize:12; elide:Text.ElideRight }
            Text { text:modelData.online?(modelData.watts===null?"Connected":details.formatted(modelData.watts," W input",1)):"Disconnected"; color:"#deebfc"; font.pixelSize:12 }
        }
    }
    Text { Layout.fillWidth:true; text:"Battery power is not total wall power or the charger's rated wattage. Readings depend on your hardware; unavailable measurements are shown as Not reported."; color:"#b5c9e3"; font.pixelSize:12; wrapMode:Text.WordWrap }
}
