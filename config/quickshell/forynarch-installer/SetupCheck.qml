import QtQuick
import QtQuick.Controls
CheckBox {
    id:check
    implicitHeight:44
    spacing:10
    Keys.onReturnPressed:{checked=!checked;toggled();}
    Keys.onEnterPressed:{checked=!checked;toggled();}
    indicator:Rectangle {
        x:0;y:(check.height-height)/2;width:18;height:18;radius:3
        color:check.checked?"#9acbff":"#142438"
        border.color:check.activeFocus?"#e0efff":check.enabled?"#8aabc9":"#64788f"
        border.width:check.activeFocus?2:1
        Text {anchors.centerIn:parent;text:"✓";visible:check.checked;color:"#102137";font.pixelSize:13;font.weight:Font.Bold}
    }
    contentItem:Text {
        leftPadding:check.indicator.width+check.spacing
        text:check.text;textFormat:Text.PlainText;verticalAlignment:Text.AlignVCenter
        font.pixelSize:13;color:check.enabled?"#dceaff":"#a1b2c6"
    }
}
