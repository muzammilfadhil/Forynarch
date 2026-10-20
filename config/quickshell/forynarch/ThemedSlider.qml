import QtQuick
import QtQuick.Controls
Slider {
    id:slider
    property color accent:"#9acbff"
    implicitHeight:32;implicitWidth:180
    background:Rectangle {
        x:slider.leftPadding;y:slider.topPadding+slider.availableHeight/2-height/2
        width:slider.availableWidth;height:7;radius:4;color:"#354156"
        Rectangle {width:slider.visualPosition*parent.width;height:parent.height;radius:4;color:slider.accent}
    }
    handle:Rectangle {
        x:slider.leftPadding+slider.visualPosition*(slider.availableWidth-width);y:slider.topPadding+slider.availableHeight/2-height/2
        width:16;height:22;radius:8;color:"#dbeaff";border.width:slider.activeFocus?2:0;border.color:slider.accent
    }
}
