import QtQuick
import Quickshell
import Quickshell.Wayland
import "WidgetLayout.js" as WidgetLayout
Scope {
    id:surface
    required property var controller
    required property var cards
    Variants {
        model:Quickshell.screens
        Scope {
            id:output
            required property var modelData
            readonly property real widgetScale:Math.min(controller.widgetScale,Math.max(0.5,(modelData.height-140)/224))
            WidgetEditor {screen:output.modelData;controller:surface.controller;scaleValue:output.widgetScale;visible:controller.widgetEditing}
            Variants {
                model:controller.widgetOrder.filter(key=>controller.widgetKeys.includes(key)&&controller.widgetEnabled(key))
                PanelWindow {
                    id:tile
                    required property string modelData
                    screen:output.modelData
                    readonly property real cardHeight:cardLoader.item&&Number.isFinite(cardLoader.item.height)&&cardLoader.item.height>0?cardLoader.item.height:WidgetLayout.height(modelData,controller.customWidgetHeights)
            readonly property var point:WidgetLayout.position(controller.widgetPositions,screen.name,modelData,controller.widgetOrder.filter(key=>controller.widgetKeys.includes(key)&&controller.widgetEnabled(key)).indexOf(modelData),screen.width,screen.height,output.widgetScale,controller.widgetsRight,controller.widgetOrder.filter(key=>controller.widgetKeys.includes(key)&&controller.widgetEnabled(key)),controller.customWidgetHeights)
                    property real dragX:point.x
                    property real dragY:point.y
                    property bool dragging:false
                    anchors {left:true;top:true}
                    margins {left:tile.dragging?tile.dragX:tile.point.x;top:tile.dragging?tile.dragY:tile.point.y}
                    implicitWidth:Math.ceil(224*output.widgetScale)
                    implicitHeight:Math.ceil(cardHeight*output.widgetScale)
                    color:"transparent";exclusionMode:ExclusionMode.Ignore
                    WlrLayershell.namespace:"forynarch-widgets"
                    WlrLayershell.layer:controller.widgetEditing?WlrLayer.Overlay:WlrLayer.Bottom
                    WlrLayershell.keyboardFocus:controller.widgetEditing?WlrKeyboardFocus.OnDemand:WlrKeyboardFocus.None
                    Item {
                        width:224;height:tile.cardHeight
                        scale:output.widgetScale;transformOrigin:Item.TopLeft
                        Loader {
                            id:cardLoader
                    sourceComponent:WidgetLayout.keys.includes(tile.modelData)?surface.cards[WidgetLayout.keys.indexOf(tile.modelData)]:customCard
                    Component {id:customCard;CustomWidget {controller:surface.controller;specification:controller.customWidgets.find(row=>row.key===tile.modelData)}}
                }
                    }
                    Rectangle {anchors.fill:parent;visible:controller.widgetEditing;color:"transparent";radius:18;border.color:controller.accent;border.width:2}
                    MouseArea {
                        anchors.fill:parent;enabled:controller.widgetEditing
                        cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
                        property real startX:0;property real startY:0
                        onPressed:mouse=>{forceActiveFocus();tile.dragX=tile.point.x;tile.dragY=tile.point.y;startX=mouse.x;startY=mouse.y;tile.dragging=true;}
                        onPositionChanged:mouse=>{if(!pressed)return;tile.dragX=Math.max(0,Math.min(tile.screen.width-tile.width,tile.dragX+mouse.x-startX));tile.dragY=Math.max(64,Math.min(tile.screen.height-tile.height,tile.dragY+mouse.y-startY));}
                        onReleased:{controller.placeWidget(tile.screen.name,tile.modelData,tile.dragX,tile.dragY,tile.screen.width,tile.screen.height,output.widgetScale);tile.dragging=false;}
                        onCanceled:tile.dragging=false
                        Accessible.role:Accessible.Button
                        Accessible.name:"Move "+tile.modelData+" widget"
                        Keys.onPressed:event=>{
                            if(event.key===Qt.Key_Escape){controller.finishWidgetEdit(false);event.accepted=true;return;}
                            var dx=event.key===Qt.Key_Right?24:event.key===Qt.Key_Left?-24:0;
                            var dy=event.key===Qt.Key_Down?24:event.key===Qt.Key_Up?-24:0;
                            if(dx||dy){controller.placeWidget(tile.screen.name,tile.modelData,tile.point.x+dx,tile.point.y+dy,tile.screen.width,tile.screen.height,output.widgetScale);event.accepted=true;}
                        }
                    }
                }
            }
        }
    }
}
