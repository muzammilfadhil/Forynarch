import QtQuick
import Quickshell
import Quickshell.Wayland

Variants {
    required property var controller
    model: Quickshell.screens
    PanelWindow {
        id: overlay
        required property var modelData
        screen: modelData
        visible: controller.snapPreview.monitor === modelData.name && controller.snapPreview.region !== ""
        anchors {left:true;right:true;top:true;bottom:true}
        color:"transparent"
        exclusionMode:ExclusionMode.Ignore
        mask:Region {}
        WlrLayershell.namespace:"forynarch-snap"
        WlrLayershell.layer:WlrLayer.Overlay
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        readonly property var monitor: controller.snapMonitors.find(m => m.name === modelData.name)
        readonly property var reserved: monitor?.reserved || [0,controller.bottomPanel?0:64,0,controller.bottomPanel?64:0]
        readonly property int count: controller.windowState.windows.filter(w => !w.minimized && w.monitor === monitor?.id).length
        readonly property string region: controller.snapPreview.region
        readonly property real trayWidth: Math.min(488,screen.width-32)
        readonly property var choices: [
            {region:"left",label:"Left",x:0,y:0,w:.5,h:1},
            {region:"top-left",label:"Top left",x:0,y:0,w:.5,h:.5},
            {region:"top",label:"Top",x:0,y:0,w:1,h:.5},
            {region:"top-right",label:"Top right",x:.5,y:0,w:.5,h:.5},
            {region:"right",label:"Right",x:.5,y:0,w:.5,h:1}
        ]
        readonly property var box: {
            const width=screen.width-reserved[0]-reserved[2];
            const height=screen.height-reserved[1]-reserved[3];
            const corner=region.includes("-");
            const halfWidth=["left","right"].includes(region)||region.includes("-");
            const x=region.endsWith("right") ? .5 : 0;
            const y=region==="bottom"||(corner&&region.startsWith("bottom")) ? .5 : 0;
            const halfHeight=region==="top"||region==="bottom"||corner;
            const outside=controller.snapStyle.screenMargin??14;
            const inside=controller.snapStyle.windowGap??6;
            return {x:reserved[0]+x*width+(x===0?outside:inside)+1,
                    y:reserved[1]+y*height+(y===0?outside:inside)+1,
                    width:Math.max(1,(halfWidth ? .5 : 1)*width-(halfWidth?outside+inside:outside*2)-2),
                    height:Math.max(1,(halfHeight ? .5 : 1)*height-(halfHeight?outside+inside:outside*2)-2)};
        }
        Rectangle {
            x:overlay.box.x;y:overlay.box.y;width:overlay.box.width;height:overlay.box.height
            radius:controller.snapStyle.cornerRadius??10;color:"#269acbff";border.width:2;border.color:controller.accent
            Text {anchors.centerIn:parent;text:overlay.region==="maximize"?"Maximize":"Snap window";
                color:"#e5efff";font.pixelSize:18;font.weight:Font.DemiBold}
        }
        Rectangle {
            visible:controller.snapPreview.choices === true
            x:(overlay.width-width)/2;y:Math.max(8,overlay.reserved[1]+8)
            width:overlay.trayWidth;height:72;radius:12;color:"#101b2a";border.width:1;border.color:"#39536f"
            Row {
                anchors.fill:parent;anchors.margins:8;spacing:8
                Repeater {
                    model:overlay.choices
                    Rectangle {
                        required property var modelData
                        width:(overlay.trayWidth-48)/5;height:56;radius:8
                        color:overlay.region===modelData.region?"#284563":"#1b2a3b"
                        border.width:overlay.region===modelData.region?1:0;border.color:controller.accent
                        Rectangle {
                            anchors.horizontalCenter:parent.horizontalCenter;y:7;width:42;height:24;radius:3;color:"#0b1420"
                            Rectangle {x:2+38*modelData.x;y:2+20*modelData.y;width:38*modelData.w;height:20*modelData.h;radius:2;color:controller.accent}
                        }
                        Text {anchors.horizontalCenter:parent.horizontalCenter;y:36;text:modelData.label;color:"#e5efff";font.pixelSize:11}
                    }
                }
            }
        }
    }
}
