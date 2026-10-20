import QtQuick

GlassCard {
    id: card
    required property var controller
    required property var specification
    width: 224
    height: specification?.height || 112
    glass: controller.glass
    frost: controller.frost
    radius: 22
    clip: true
    function ink(value) { return value === "accent" ? controller.accent : value === "muted" ? "#a5b9d2" : value === "text" || !value ? "#e5efff" : value; }
    function format(value) {
        const metrics = controller.widgetMetrics;
        const tokens = {time:controller.timeText, date:Qt.formatDateTime(controller.now,"dddd, dd MMM"), user:controller.userName,
            memoryUsed:((metrics.used||0)/1e9).toFixed(2)+" GB", memoryTotal:((metrics.total||0)/1e9).toFixed(2)+" GB",
            batteryPercent:metrics.capacity>=0?metrics.capacity+"%":"Not available",
            trackTitle:controller.player?.trackTitle||"Nothing playing", trackArtist:controller.player?.trackArtist||""};
        return String(value||"").replace(/\{(\w+)\}/g, (match,key)=>tokens[key]??match);
    }
    Column {
        anchors { left:parent.left; right:parent.right; top:parent.top; margins:16 }
        spacing: 10
        Repeater {
            model: card.specification?.items || []
            Loader {
                id: row
                required property var modelData
                width: parent.width
                sourceComponent: modelData.kind === "divider" ? divider : modelData.kind === "meter" ? meter : textItem
                Component {
                    id: textItem
                    Text {
                        width: row.width
                        text: row.modelData.kind === "clock" ? Qt.formatDateTime(card.controller.now,row.modelData.format) : card.format(row.modelData.text)
                        textFormat: Text.PlainText
                        color: card.ink(row.modelData.color)
                        font { family:"Adwaita Sans"; pixelSize:row.modelData.size||13; weight:row.modelData.kind==="clock"?Font.Medium:Font.Normal }
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
                Component { id:divider; Rectangle { width:row.width; height:1; color:"#30435b" } }
                Component {
                    id: meter
                    Column {
                        width: row.width; spacing: 7
                        readonly property bool memory: row.modelData.source === "memory"
                        readonly property real amount: memory ? (card.controller.widgetMetrics.used||0)/Math.max(1,card.controller.widgetMetrics.total||1) : Math.max(0,card.controller.widgetMetrics.capacity)/100
                        Text {
                            width: parent.width; textFormat:Text.PlainText; font.pixelSize:12; color:"#cbd9ed"; elide:Text.ElideRight
                            text:(row.modelData.label||(parent.memory?"Memory":"Battery"))+" · "+card.format(parent.memory?"{memoryUsed}":"{batteryPercent}")
                        }
                        Rectangle {
                            width:parent.width; height:4; radius:2; color:"#293d55"
                            Rectangle { width:parent.width*Math.max(0,Math.min(1,parent.parent.amount)); height:4; radius:2; color:card.controller.accent }
                        }
                    }
                }
            }
        }
    }
}
