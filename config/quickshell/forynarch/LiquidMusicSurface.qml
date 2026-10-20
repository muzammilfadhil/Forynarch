import QtQuick
import "WidgetPalette.js" as Palette
Item {
    id: surface
    property bool glass:true
    property bool motion:true
    property real radius:24
    property color accent:"#96c8ff"
    property real glint:0
GlassCard {anchors.fill:parent;radius:surface.radius;glass:surface.glass;color:surface.glass?Palette.surface:Palette.opaqueSurface;border.color:Palette.edge}
    Rectangle {anchors.fill:parent;anchors.margins:2;radius:Math.max(0,surface.radius-2);color:"transparent";border.width:1;border.color:"#1896c8ff"}
    Canvas {
        id:rim;anchors.fill:parent;visible:surface.glass
        function paintRim(){requestPaint();}
        onWidthChanged:requestPaint()
        onHeightChanged:requestPaint()
        onPaint:{
            const c=getContext("2d");c.reset();
            const r=Math.min(surface.radius,width/2,height/2),x=1,y=1,w=width-2,h=height-2;
            const light=c.createLinearGradient(0,0,width,height);
light.addColorStop(0,"#92b3d0");light.addColorStop(.32,"#49617b");light.addColorStop(.65,"#273a51");light.addColorStop(1,"#6489a9");
            c.strokeStyle=light;c.lineWidth=1.3;c.globalAlpha=.6+surface.glint*.25;
            c.beginPath();c.moveTo(x+r,y);c.lineTo(x+w-r,y);c.quadraticCurveTo(x+w,y,x+w,y+r);
            c.lineTo(x+w,y+h-r);c.quadraticCurveTo(x+w,y+h,x+w-r,y+h);c.lineTo(x+r,y+h);
            c.quadraticCurveTo(x,y+h,x,y+h-r);c.lineTo(x,y+r);c.quadraticCurveTo(x,y,x+r,y);c.closePath();c.stroke();
        }
    }
    HoverHandler {onHoveredChanged:if(hovered&&surface.motion)gleam.restart()}
    onGlintChanged:rim.requestPaint()
    onGlassChanged:rim.requestPaint()
    SequentialAnimation {id:gleam;NumberAnimation{target:surface;property:"glint";to:1;duration:160;easing.type:Easing.OutCubic}NumberAnimation{target:surface;property:"glint";to:0;duration:360;easing.type:Easing.OutCubic}}
    onMotionChanged:if(!motion){gleam.stop();glint=0;}
}
