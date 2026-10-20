import QtQuick
import QtQuick.Controls
ComboBox {
    id:choice
    implicitHeight:44
    indicator:Text {x:choice.width-width-12;y:(choice.height-height)/2;text:"⌄";color:"#b5cce4";font.pixelSize:17}
    contentItem:Text {leftPadding:12;rightPadding:32;text:choice.displayText;textFormat:Text.PlainText;color:"#dceaff";font.pixelSize:13;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    background:Rectangle {radius:5;color:"#192c42";border.color:choice.activeFocus?"#9acbff":"#6483a3"}
    delegate:ItemDelegate {
        required property var modelData
        required property int index
        implicitHeight:44
        highlighted:choice.highlightedIndex===index
        width:choice.width
        contentItem:Text {text:choice.textRole?modelData[choice.textRole]:modelData;textFormat:Text.PlainText;color:"#dceaff";elide:Text.ElideRight;font.pixelSize:13}
        background:Rectangle {color:parent.hovered||parent.highlighted?"#365775":"#1c3048"}
    }
    popup:Popup {
        y:choice.height+4;width:choice.width
        implicitHeight:Math.min(300,list.contentHeight+12)
        padding:6
        background:Rectangle {color:"#1c3048";radius:5;border.color:"#6483a3"}
        contentItem:ListView {id:list;clip:true;model:choice.popup.visible?choice.delegateModel:null;currentIndex:choice.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator {}}
    }
}
