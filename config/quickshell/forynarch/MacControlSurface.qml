// Adapted from MacShell CCTile/GGlass (MIT). See MACSHELL-SOURCES.md.
import QtQuick

Item {
    id:surface
    required property var center
    property real radius:34
    property real opticalThickness:22
    property real refractionStrength:1
    property real shadowStrength:0.45
    readonly property point origin: {
        const progress=center.progress;
        const offset=center.scrollOffset;
        const placement=surface.x+surface.y;
        const layout=center.layoutRevision;
        return surface.mapToItem(center.backdrop,0,0);
    }
    Rectangle{
objectName:"macControlBackdrop"
        anchors.fill:parent;radius:surface.radius
        color:surface.center.controller.glass?"#cf16283e":"#16283e"
        border.width:surface.center.controller.glass?0:1;border.color:"#85858d"
visible:!surface.center.singlePanel
    }
    LiquidGlass{
        id:glass;anchors.fill:parent;backdrop:surface.center.backdrop
        enabledEffect:surface.center.controller.glass&&!surface.center.singlePanel
        sampleRect:Qt.rect(surface.origin.x,surface.origin.y,surface.width,surface.height)
        cornerRadius:surface.radius;frost:surface.center.controller.frost
        opticalThickness:surface.opticalThickness;refractionStrength:surface.refractionStrength;shadowStrength:surface.shadowStrength
        onFailedChanged:if(failed)surface.center.tileShaderFailed=true
    }
    Rectangle{
        anchors.fill:parent;radius:surface.radius
        visible:surface.center.singlePanel
        color:"#3016283e";border.width:1;border.color:"#2285858d"
    }
}
