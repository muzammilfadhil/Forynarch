import QtQuick
import QtQuick.Controls
Button {
    id:button
    property bool primary:false
    property bool quiet:false
    implicitHeight:44
    implicitWidth:Math.max(100, label.implicitWidth+32)
    Keys.onReturnPressed:clicked()
    Keys.onEnterPressed:clicked()
    contentItem:Text {id:label;text:button.text;font.pixelSize:13;font.weight:Font.DemiBold;color:!button.enabled?"#9aacbf":button.primary?"#112239":"#dceaff";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
    background:Rectangle {radius:6;color:!button.enabled?"#1a293b":button.primary?(button.hovered?"#b6dcff":"#9acbff"):button.quiet?(button.hovered?"#203247":"transparent"):(button.hovered?"#2b4059":"#213349");border.color:button.activeFocus?"#dceaff":button.primary||button.quiet?"transparent":"#39506a";border.width:1}
}
