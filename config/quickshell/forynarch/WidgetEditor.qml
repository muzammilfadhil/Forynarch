import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "WidgetPacks.js" as Packs
PanelWindow {
    id:editor
    required property var controller
    required property real scaleValue
    anchors {left:true;right:true;top:true;bottom:true}
    exclusionMode:ExclusionMode.Ignore
    color:"#50101c2d"
    WlrLayershell.namespace:"forynarch-widget-editor"
    WlrLayershell.layer:WlrLayer.Top
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.OnDemand
    Canvas {
        anchors.fill:parent;visible:controller.widgetGrid
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        onVisibleChanged:if(visible)requestPaint()
        onPaint:{var ctx=getContext("2d");ctx.clearRect(0,0,width,height);ctx.strokeStyle="#507f9fbd";ctx.lineWidth=1;ctx.beginPath();for(var x=0;x<width;x+=24){ctx.moveTo(x,0);ctx.lineTo(x,height);}for(var y=0;y<height;y+=24){ctx.moveTo(0,y);ctx.lineTo(width,y);}ctx.stroke();}
    }
    Rectangle {
        anchors.top:parent.top;anchors.horizontalCenter:parent.horizontalCenter;anchors.topMargin:8
        width:Math.min(parent.width-24,760);height:tools.implicitHeight+24;radius:16;color:"#f2101c2d";border.color:"#6483a3"
        ColumnLayout {
            id:tools;anchors.fill:parent;anchors.margins:12;spacing:8
            RowLayout {
                Layout.fillWidth:true
                Text {text:"Edit widgets";font.pixelSize:16;font.bold:true;color:"#e5efff";Layout.fillWidth:true}
                ActionButton {label:"Cancel";implicitHeight:44;onClicked:controller.finishWidgetEdit(false)}
                ActionButton {label:"Save layout";selected:true;implicitHeight:44;onClicked:controller.finishWidgetEdit(true)}
            }
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
                Repeater {model:[{id:"left",label:"Left"},{id:"right",label:"Right"},{id:"balanced",label:"Balanced"}]
                    ActionButton {required property var modelData;label:modelData.label;implicitHeight:44;onClicked:controller.widgetPreset(editor.screen.name,modelData.id,editor.screen.width,editor.screen.height,editor.scaleValue)}
                }
                ActionButton {label:"Snap to grid";selected:controller.widgetSnap;implicitHeight:44;onClicked:controller.widgetSnap=!controller.widgetSnap}
                ActionButton {label:"Show grid";selected:controller.widgetGrid;implicitHeight:44;onClicked:controller.widgetGrid=!controller.widgetGrid}
            }
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
            Repeater {model:controller.widgetCatalog
                    ActionButton {required property var modelData;label:modelData.label;selected:controller.widgetEnabled(modelData.id);implicitHeight:44;onClicked:controller.setWidget(modelData.id,!controller.widgetEnabled(modelData.id))}
                }
                ActionButton {label:"Smaller";implicitHeight:44;enabled:controller.widgetScale>0.8;onClicked:controller.setWidgetScale(controller.widgetScale>1?1:0.8)}
                ActionButton {label:"Larger";implicitHeight:44;enabled:controller.widgetScale<1.2;onClicked:controller.setWidgetScale(controller.widgetScale<1?1:1.2)}
            }
            ActionButton {label:"Import / manage packs";implicitHeight:44;onClicked:controller.openWidgetPacks()}
            Text {text:"Drag a widget to move it. Save to keep this layout. Escape cancels.";color:"#b5c9e3";wrapMode:Text.WordWrap;Layout.fillWidth:true;font.pixelSize:12}
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
                Repeater {model:Packs.packs
                    ActionButton {required property var modelData;label:modelData.label+" pack";hint:modelData.description;implicitHeight:40;onClicked:controller.applyWidgetPack(modelData.id)}
                }
            }
        }
        focus:true
        Keys.onEscapePressed:controller.finishWidgetEdit(false)
    }
}
