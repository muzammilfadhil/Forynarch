// Adapted from MacShell CCSlider (MIT). See MACSHELL-SOURCES.md.
import QtQuick
import QtQuick.Controls

Slider{
    id:slider
    property string glyph:"sun"
    property string label:""
    from:0;to:1;stepSize:0.01
    implicitHeight:28
    leftPadding:28;rightPadding:26
    Accessible.name:label
    background:Item{
        Rectangle{x:28;width:Math.max(1,parent.width-54);height:4;radius:2;anchors.verticalCenter:parent.verticalCenter;color:"#85858d"}
        Rectangle{x:28;width:Math.max(1,parent.width-54)*slider.visualPosition;height:4;radius:2;anchors.verticalCenter:parent.verticalCenter;color:slider.enabled?"#f5f5f7":"#85858d"}
        MacControlGlyph{x:4;width:16;height:16;anchors.verticalCenter:parent.verticalCenter;kind:slider.glyph;level:1;color:"#f5f5f7"}
        MacControlGlyph{x:parent.width-20;width:16;height:16;anchors.verticalCenter:parent.verticalCenter;kind:slider.glyph;level:3;color:"#c5c5c9"}
    }
    handle:Rectangle{
        x:slider.leftPadding+slider.visualPosition*slider.availableWidth-width/2
        anchors.verticalCenter:parent.verticalCenter;width:slider.activeFocus||slider.pressed?12:0;height:12;radius:6;color:"#f5f5f7"
    }
}
