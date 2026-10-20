// Control Center port from 0-ss/MacShell MacBar.qml, MIT. See MACSHELL-SOURCES.md.
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "ControlCenterLayout.js" as Layout

PanelWindow {
    id:window
    required property var controller
    property bool ready:false
    property bool editing:false
    readonly property bool audioOpen:controller.controlAudioRequested
    property bool wifiOpen:false
    readonly property bool detailOpen:audioOpen||wifiOpen
    function openWifi(){wifiOpen=true;controller.controlAudioRequested=false;editing=false;if(scroll.contentItem)scroll.contentItem.contentY=0;controller.quickControlActions.refreshWifi();}
    function closeWifi(){wifiOpen=false;controller.quickControlActions.refreshWifi();if(scroll.contentItem)scroll.contentItem.contentY=0;}
    function openAudio(){wifiOpen=false;controller.controlAudioRequested=true;if(scroll.contentItem)scroll.contentItem.contentY=0;}
    function closeAudio(){controller.controlAudioRequested=false;if(scroll.contentItem)scroll.contentItem.contentY=0;}
    property int layoutRevision:0
    property bool tileShaderFailed:false
    readonly property var backdrop:screenFrame
    readonly property real progress:reveal.progress
    readonly property real scrollOffset:scroll.contentItem?.contentY??0
    readonly property bool singlePanel:controller.controlCenterSurface==="panel"||detailOpen
    readonly property var plan:Layout.layout(controller.controlCenterControls)
readonly property var glassStatus:({ready:ready,captured:screenFrame.hasContent,liquid:controller.glass&&screenFrame.hasContent&&panelGlass.backendSupported&&!panelGlass.failed&&!tileShaderFailed,failed:panelGlass.failed||tileShaderFailed,style:controller.controlCenterSurface,columns:4,rows:plan.rows,editing:editing,audioOpen:audioOpen})
    anchors{left:true;right:true;top:true;bottom:true}
    mask:Region {x:0;y:controller.bottomPanel?0:controller.panelReserved;width:window.width;height:Math.max(0,window.height-controller.panelReserved)}
    color:"transparent";exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"forynarch-controls"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:controller.controlOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    Component.onCompleted:controller.quickControlActions.refresh()
    ScreencopyView{id:screenFrame;width:window.width;height:window.height;opacity:0;captureSource:null;live:false;paintCursor:false;onHasContentChanged:if(hasContent)window.ready=true}
    Timer{interval:24;running:true;onTriggered:{if(controller.glass){screenFrame.captureSource=window.screen;screenFrame.captureFrame();}else window.ready=true;}}
    Timer{interval:220;running:true;onTriggered:window.ready=true}
    MouseArea{anchors.fill:parent;onClicked:controller.dismissControls()}
    MotionSurface{
        id:reveal;controller:window.controller;shown:controller.controlOpen&&window.ready
        readonly property real barOffset:controller.panelReserved+6
        width:Math.min(364,parent.width-24)
        height:Math.min(parent.height-barOffset-16,content.implicitHeight+24)
            Behavior on height {enabled:controller.motion;NumberAnimation{duration:220;easing.type:Easing.OutCubic}}
        x:parent.width-width-10;y:controller.bottomPanel?parent.height-height-barOffset:barOffset
Rectangle{objectName:"macPanelBackdrop";anchors.fill:parent;radius:24;color:"#16283e";border.width:1;border.color:"#85858d";visible:window.singlePanel}
        LiquidGlass{id:panelGlass;anchors.fill:parent;backdrop:screenFrame;sampleRect:Qt.rect(reveal.x,reveal.y,reveal.width,reveal.height);enabledEffect:controller.glass&&(window.singlePanel||window.audioOpen)&&window.ready;cornerRadius:24;frost:controller.frost;opticalThickness:26}
        MouseArea{anchors.fill:parent}
        FocusScope{
            anchors.fill:parent;focus:true
            Component.onCompleted:forceActiveFocus()
            Keys.onEscapePressed:{if(window.wifiOpen)window.closeWifi();else if(window.audioOpen)window.closeAudio();else if(window.editing)window.editing=false;else controller.dismissControls();}
            ScrollView{
                id:scroll;anchors.fill:parent;anchors.margins:2;clip:true
                contentWidth:availableWidth;contentHeight:content.implicitHeight+20
                ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ScrollBar.vertical.policy:ScrollBar.AsNeeded
                Column{
                    id:content;x:10;y:10;width:scroll.availableWidth-20;spacing:10
                    Item{
                        id:grid;width:parent.width;height:Math.max(66,window.plan.rows*76-10);visible:!window.detailOpen
                        readonly property real cellWidth:(width-30)/4
                        Text{anchors.centerIn:parent;visible:window.plan.items.length===0;width:parent.width;text:"Use Edit Controls to add controls.";wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;color:"#c5c5c9";font.pixelSize:12}
                        Repeater{
                            model:Layout.catalog
                            Item{
                                id:host;required property var modelData
                                readonly property var slot:window.plan.items.find(item=>item.id===modelData.id)||null
                                property real dx:0
                                property real dy:0
                                property bool dragging:false
                                property real entry:controller.motion?0:1
                                function enter(){if(!controller.motion||!slot){entry=1;return;}entry=0;entryAnimation.restart();}
                                Component.onCompleted:if(window.ready)enter()
                                Connections{target:window;function onReadyChanged(){if(window.ready)host.enter();}}
                                Connections{target:controller;function onMotionChanged(){if(!controller.motion){entryAnimation.stop();host.entry=1;}}}
                                SequentialAnimation{
                                    id:entryAnimation
                                    PauseAnimation{duration:host.slot?Math.min(220,host.slot.row*55+host.slot.col*18):0}
                                    NumberAnimation{target:host;property:"entry";from:0;to:1;duration:460;easing.type:Easing.OutBack;easing.overshoot:1.8}
                                }
                                onEntryChanged:window.layoutRevision++
                                transform:Translate{y:(1-host.entry)*16}
                                opacity:Math.max(0,Math.min(1,entry*1.6))
                                function move(delta){const ids=controller.controlCenterControls;const index=ids.indexOf(modelData.id);const target=index+delta;if(target<0||target>=ids.length)return;const next=ids.slice();next.splice(index,1);next.splice(target,0,modelData.id);controller.setControlCenterControls(next);}
                                activeFocusOnTab:window.editing
                                Accessible.role:Accessible.Grouping;Accessible.name:modelData.label
                                Accessible.description:"In edit mode, use Left and Right to reorder or Delete to remove."
                                Keys.onLeftPressed:if(window.editing)move(-1)
                                Keys.onRightPressed:if(window.editing)move(1)
                                Keys.onDeletePressed:if(window.editing)controller.setControlCenterControls(controller.controlCenterControls.filter(id=>id!==modelData.id))
                                visible:slot!==null
                                x:(slot?slot.col*(grid.cellWidth+10):0)+dx
                                y:(slot?slot.row*76:0)+dy
                                width:slot?slot.w*grid.cellWidth+(slot.w-1)*10:0
                                height:slot?slot.h*66+(slot.h-1)*10:0
                                z:dragging?100:0;scale:dragging?1.04:1
                                onXChanged:window.layoutRevision++
                                onYChanged:window.layoutRevision++
                                Behavior on x{enabled:!host.dragging&&controller.motion;NumberAnimation{duration:180;easing.type:Easing.OutCubic}}
                                Behavior on y{enabled:!host.dragging&&controller.motion;NumberAnimation{duration:180;easing.type:Easing.OutCubic}}
                                Behavior on scale{NumberAnimation{duration:controller.motion?110:0;easing.type:Easing.OutCubic}}
                                Loader{anchors.fill:parent;active:host.slot!==null;sourceComponent:MacControlTile{center:window;controlId:host.modelData.id}}
                                Rectangle{anchors.fill:parent;visible:host.activeFocus&&window.editing;color:"transparent";radius:34;border.width:2;border.color:"#f5f5f7";z:45}
                                MouseArea{
                                    anchors.fill:parent;enabled:window.editing;z:50
                                    cursorShape:host.dragging?Qt.ClosedHandCursor:Qt.OpenHandCursor
                                    property point origin:Qt.point(0,0)
                                    onPressed:mouse=>{host.forceActiveFocus();origin=mapToItem(grid,mouse.x,mouse.y);host.dragging=true;}
                                    onPositionChanged:mouse=>{if(!pressed)return;const p=mapToItem(grid,mouse.x,mouse.y);host.dx=p.x-origin.x;host.dy=p.y-origin.y;}
                                    onReleased:mouse=>{
                                        const p=mapToItem(grid,mouse.x,mouse.y);
                                        const target=window.plan.items.find(item=>p.x>=item.col*(grid.cellWidth+10)&&p.x<(item.col+item.w)*(grid.cellWidth+10)-10&&p.y>=item.row*76&&p.y<(item.row+item.h)*76-10);
                                        host.dragging=false;host.dx=0;host.dy=0;
                                        if(target?.id!==host.modelData.id)controller.setControlCenterControls(Layout.reorder(controller.controlCenterControls,host.modelData.id,target?.id||""));
                                    }
                                    onCanceled:{host.dragging=false;host.dx=0;host.dy=0;}
                                }
                                AbstractButton{
                                    visible:window.editing;z:60;x:-5;y:-5;width:22;height:22
                                    Accessible.name:"Remove "+host.modelData.label
                                    background:Rectangle{radius:11;color:"#53677f";border.width:parent.activeFocus?2:1;border.color:"#f5f5f7"}
                                    contentItem:Text{text:"−";font.pixelSize:18;color:"#ffffff";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                                    onClicked:controller.setControlCenterControls(controller.controlCenterControls.filter(id=>id!==host.modelData.id))
                                }
                            }
                        }
                    }
                    Column{
                        visible:!window.audioOpen&&window.editing&&additions.count>0;width:parent.width;spacing:8
                        Text{text:"Add Controls";color:"#c5c5c9";font.pixelSize:12;font.weight:Font.DemiBold}
                        Flow{
                            width:parent.width;spacing:8
                            Repeater{
                                id:additions;model:Layout.catalog.filter(d=>!controller.controlCenterControls.includes(d.id))
                                MacControlPill{required property var modelData;center:window;text:"+ "+modelData.label;onClicked:controller.setControlCenterControls(controller.controlCenterControls.concat([modelData.id]))}
                            }
                        }
                    }
                    Text{visible:controller.quickControlActions.error!=="";width:parent.width;text:controller.quickControlActions.error;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:"#ffc1b8";font.pixelSize:12}
                    Loader{active:window.audioOpen;width:parent.width;sourceComponent:MacAudioDetails{center:window}}
                    Loader{active:window.wifiOpen;width:parent.width;sourceComponent:Column{
                        spacing:14
                        MacControlPill{center:window;text:"‹ Control Center";onClicked:window.closeWifi()}
                        NetworkPage{width:parent.width;controller:window.controller;compact:true}
                    }}
                    Item{
                        width:parent.width;height:28;visible:!window.detailOpen
                        Row{
                            anchors.centerIn:parent;spacing:8
                            MacControlPill{visible:window.editing;center:window;text:"Reset";onClicked:controller.setControlCenterControls(Layout.defaults.slice())}
                            MacControlPill{center:window;text:window.editing?"Done":"Edit Controls";onClicked:window.editing=!window.editing}
                            MacControlButton{center:window;diameter:28;compact:true;glyph:"gear";label:"Control Center appearance";onClicked:controller.openSettings("Panel")}
                        }
                    }
                }
            }
        }
    }
}
