import QtQuick
import QtQuick.Controls

ComboBox {
    id: choice
    property var choices: []
    property var selectedValue
    signal chosen(var value)
    model:choices; textRole:"label"; valueRole:"value"
    currentIndex:Math.max(0,choices.findIndex(c=>c.value===selectedValue))
    implicitHeight:38; implicitWidth:160
    onActivated:chosen(choices[currentIndex].value)
    contentItem:Text {text:choice.displayText;color:choice.enabled?"#dceaff":"#7890ac";font.pixelSize:12;verticalAlignment:Text.AlignVCenter;leftPadding:12;rightPadding:28;elide:Text.ElideRight}
    background:Rectangle {radius:10;color:"#24374e";border.width:1;border.color:choice.activeFocus?"#9acbff":"#91b5dc"}
    indicator:Icon {x:choice.width-width-10;y:(choice.height-height)/2;name:"down";size:14;ink:"#abc9e9"}
    popup:Popup {
        y:choice.height+6;width:choice.width;height:Math.min(250,contentItem.implicitHeight+12);padding:6
        background:Rectangle {color:"#192a3f";radius:12;border.width:1;border.color:"#3d5776"}
        contentItem:ListView {clip:true;implicitHeight:contentHeight;model:choice.popup.visible?choice.delegateModel:null;currentIndex:choice.highlightedIndex;ScrollBar.vertical:ScrollBar {}}
    }
    delegate:ItemDelegate {
        required property var modelData
        required property int index
        width:choice.width-12;height:34;highlighted:choice.highlightedIndex===index
        contentItem:Text {text:modelData.label;color:"#e1edff";font.pixelSize:12;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
        background:Rectangle {radius:7;color:parent.highlighted?"#345678":"transparent"}
    }
}
