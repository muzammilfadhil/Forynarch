import QtQuick
import QtQuick.Layouts
GlassCard {
    id:card
    required property var controller
    required property string kind
    width:224;height:kind==="focus"?158:kind==="shortcuts"?156:kind==="launchpad"?154:112
    glass:controller.glass;frost:controller.frost;radius:22
    readonly property string heading:({digital:"LOCAL TIME",focus:"FOCUS",system:"MEMORY",battery:"BATTERY",launchpad:"QUICK LAUNCH",shortcuts:"KEYBOARD"})[kind]
    ColumnLayout {
        anchors.fill:parent;anchors.margins:16;spacing:8
        Text {text:card.heading;color:controller.accent;font.family:"Adwaita Sans";font.pixelSize:10;font.letterSpacing:1.4}
        Text {
            visible:card.kind!=="launchpad"&&card.kind!=="shortcuts"
            text:card.kind==="digital"?controller.timeText:card.kind==="focus"?Math.floor(controller.focusRemaining/60).toString().padStart(2,"0")+":"+(controller.focusRemaining%60).toString().padStart(2,"0"):
                card.kind==="system"?((controller.widgetMetrics.used||0)/1e9).toFixed(2)+" GB":controller.widgetMetrics.capacity>=0?controller.widgetMetrics.capacity+"%":"No battery"
            color:"#e5efff";font.family:"Adwaita Sans";font.pixelSize:card.kind==="digital"||card.kind==="focus"?30:24;font.weight:Font.Medium
        }
        Text {
            visible:["digital","system","battery","focus"].includes(card.kind)
            text:card.kind==="digital"?Qt.formatDateTime(controller.now,"dddd, dd MMM"):card.kind==="system"?"Used · "+((controller.widgetMetrics.total||0)/1e9).toFixed(1)+" GB installed":card.kind==="focus"?"25 minutes, one task":""+(controller.widgetMetrics.capacity<0?"Connected to AC power":controller.widgetMetrics.charging?"Charging":"On battery")
            color:"#a5b9d2";font.family:"Adwaita Sans";font.pixelSize:11;Layout.fillWidth:true;elide:Text.ElideRight
        }
        RowLayout {
            visible:card.kind==="focus"
            ActionButton {label:controller.focusRunning?"Pause":"Start";selected:controller.focusRunning;implicitHeight:34;onClicked:controller.focusRunning=!controller.focusRunning}
            ActionButton {label:"Reset";implicitHeight:34;onClicked:{controller.focusRunning=false;controller.focusRemaining=1500;}}
        }
        Flow {
            visible:card.kind==="launchpad";Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
            ActionButton {label:"Files";implicitHeight:34;onClicked:controller.run(["forynarch-files"])}
            ActionButton {label:"Search";implicitHeight:34;onClicked:controller.openLauncher()}
            ActionButton {label:"Terminal";implicitHeight:34;onClicked:controller.run(["forynarch-terminal"])}
            ActionButton {label:"Emoji";implicitHeight:34;onClicked:controller.openEmoji()}
        }
        Text {visible:card.kind==="shortcuts";text:controller.shortcutLabel("Search apps","Super + Space")+"    Search\n"+controller.shortcutLabel("Files","Super + E")+"    Files\n"+controller.shortcutLabel("Emoji, symbols and GIFs","Super + .")+"    Emoji\n"+controller.shortcutLabel("Float / tile","Super + V")+"    Float / tile";lineHeight:1.5;color:"#d3dff0";font.family:"Adwaita Sans";font.pixelSize:12}
    }
}
