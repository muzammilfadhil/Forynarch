// Adapted from MacShell CCPill (MIT). See MACSHELL-SOURCES.md.
import QtQuick
import QtQuick.Controls

AbstractButton{
    id:pill
    required property var center
    implicitWidth:caption.implicitWidth+32;implicitHeight:28
    background:Item{
        MacControlSurface{anchors.fill:parent;center:pill.center;radius:14;opticalThickness:14;refractionStrength:0.6;shadowStrength:0.4}
        Rectangle{anchors.fill:parent;radius:14;color:pill.hovered?"#28ffffff":"transparent";border.width:pill.activeFocus?2:0;border.color:"#f5f5f7"}
    }
    contentItem:Text{id:caption;text:pill.text;textFormat:Text.PlainText;color:"#f5f5f7";font.pixelSize:12;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
}
