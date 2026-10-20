// Adapted from MacShell CCBtn (MIT). See MACSHELL-SOURCES.md.
import QtQuick
import QtQuick.Controls

Item {
    id:button
    required property var center
    readonly property var controller:center.controller
    property string glyph:""
    property string label:""
    property bool checked:false
    property bool selected:false
    property real diameter:40
    property color activeColor:"#0a84ff"
    property bool compact:false
    signal clicked()
    implicitWidth:diameter;implicitHeight:diameter
    activeFocusOnTab:enabled
    Accessible.role:Accessible.Button;Accessible.name:label
    Accessible.checkable:true;Accessible.checked:checked
    scale:mouse.pressed?0.88:1
    Behavior on scale{NumberAnimation{duration:button.controller.motion?160:0;easing.type:Easing.OutBack}}
    MacControlSurface{anchors.fill:parent;center:button.center;radius:button.diameter/2;opticalThickness:14;refractionStrength:0.6;shadowStrength:0}
    Rectangle{
        anchors.fill:parent;radius:width/2
        color:button.checked?button.activeColor:(mouse.containsMouse?"#28ffffff":"transparent")
        border.width:button.activeFocus?2:0;border.color:"#f5f5f7"
        Behavior on color{ColorAnimation{duration:button.controller.motion?320:0;easing.type:Easing.OutCubic}}
    }
    property real pop:0
    onCheckedChanged:{if(controller.motion)popAnimation.restart();else pop=0;}
    SequentialAnimation{
        id:popAnimation
        NumberAnimation{target:button;property:"pop";to:1;duration:120;easing.type:Easing.OutCubic}
        NumberAnimation{target:button;property:"pop";to:0;duration:420;easing.type:Easing.OutQuint}
    }
    MacControlGlyph{
        anchors.centerIn:parent;width:button.compact?16:21;height:width;kind:button.glyph
        color:"#f5f5f7"
        opacity:button.enabled?1:0.6
        scale:1-0.22*button.pop;rotation:(button.checked?-14:14)*button.pop
    }
    MouseArea{id:mouse;anchors.fill:parent;anchors.margins:-4;hoverEnabled:true;cursorShape:button.enabled?Qt.PointingHandCursor:Qt.ArrowCursor;onClicked:{button.forceActiveFocus();button.clicked();}}
    Keys.onSpacePressed:clicked()
    Keys.onReturnPressed:clicked()
}
