import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Item {
    id:option
    property string title:""
    property string description:""
    property bool selected:false
    Accessible.role:Accessible.RadioButton
    Accessible.name:title
    Accessible.checked:selected
    signal chosen()
    implicitHeight:Math.max(88,copy.implicitHeight+32)
    Rectangle {anchors.fill:parent;color:option.selected?"#182d45":mouse.containsMouse?"#14263b":"transparent"}
    Rectangle {height:1;anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom;color:"#2c4057"}
    Rectangle {
        x:14;y:20;width:17;height:17;radius:9;color:"transparent";border.color:option.selected?"#a5d0fa":"#617a95"
        Rectangle {anchors.centerIn:parent;width:7;height:7;radius:4;color:"#a5d0fa";visible:option.selected}
    }
    ColumnLayout {
        id:copy;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top
        anchors.leftMargin:47;anchors.rightMargin:20;anchors.topMargin:16;spacing:7
        Text {Layout.fillWidth:true;text:option.title;color:"#e0ecfa";font.pixelSize:14;font.weight:Font.DemiBold;textFormat:Text.PlainText;wrapMode:Text.WordWrap}
        SetupText {text:option.description;font.pixelSize:12}
    }
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:{option.forceActiveFocus();option.chosen();}}
    activeFocusOnTab:true
    Keys.onSpacePressed:chosen()
    Keys.onReturnPressed:chosen()
    Rectangle {anchors.fill:parent;color:"transparent";border.width:1;border.color:option.activeFocus?"#a5d0fa":"transparent"}
}
