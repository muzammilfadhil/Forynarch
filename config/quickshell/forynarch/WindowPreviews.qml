import QtQuick
import QtQuick.Layouts
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PopupWindow {
    id: popup
    required property var controller
    required property var panelWindow
    required property var application
    required property real anchorX
    property bool keyboardOpen: false
    property int page: 0
    property bool shown: true
    property double requestedAt:Date.now()
    property bool captureReady: true
    property bool loading: true
    property real reveal: 0
    Component.onCompleted: {reveal = shown?1:0;syncRows();focusFirst();}
    Behavior on reveal { enabled: controller.motion; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    function focusFirst(){if(shown&&keyboardOpen)Qt.callLater(()=>previewCards.itemAt(0)?.forceActiveFocus());}
    onKeyboardOpenChanged:focusFirst()
    onShownChanged: {reveal = shown ? 1 : 0;focusFirst();}
    Timer { interval: 2500; running: true; onTriggered: popup.loading = false }
    readonly property var metrics:controller.panelMetrics
    readonly property real cardWidth:Math.min(metrics.previewWidth,panelWindow.screen.width-40-2*metrics.previewPadding)
    readonly property real captureWidth:cardWidth-12
    readonly property real captureHeight:Math.floor(captureWidth*9/16)
    readonly property real cardHeaderHeight:Math.max(metrics.previewButtonSize+8,Math.ceil(metrics.previewTitleSize*1.4)+8)
    readonly property real cardHeight:cardHeaderHeight+captureHeight+12
    readonly property int capacity:Math.max(1,Math.min(3,Math.floor((panelWindow.screen.width-40-2*metrics.previewPadding+metrics.previewGap)/(cardWidth+metrics.previewGap))))
    readonly property var windows: application?.windows || []
    readonly property var pageWindows: windows.slice(page * capacity, (page + 1) * capacity)
    ListModel {id:previewRows}
    function syncRows(){
        const rows=pageWindows;
        for(let i=previewRows.count-1;i>=0;i--)if(!rows.some(row=>row.address===previewRows.get(i).windowAddress))previewRows.remove(i);
        rows.forEach((row,index)=>{
            if(index<previewRows.count&&previewRows.get(index).windowAddress===row.address)return;
            let found=-1;for(let i=index;i<previewRows.count;i++)if(previewRows.get(i).windowAddress===row.address){found=i;break;}
            if(found>=0)previewRows.move(found,index,1);else previewRows.insert(index,{windowAddress:row.address});
        });
    }
    onPageWindowsChanged:syncRows()
    readonly property var waylandWindows: ToplevelManager.toplevels.values
    signal dismissed()
    signal pointerEntered()
    signal pointerLeft()
    signal windowChosen(var window)
    function sourceFor(address) {
        // Match compositor addresses; titles and app IDs are not unique.
        const window = Hyprland.toplevels.values.find(window => "0x" + window.address.replace(/^0x/, "") === address);
        return waylandWindows.length && window ? window.wayland : null;
    }
    onWindowsChanged: if (page * capacity >= windows.length) page = 0
    onApplicationChanged: page = 0
    anchor.window: panelWindow
    anchor.rect.x: anchorX
    anchor.rect.y: controller.bottomPanel ? 0 : panelWindow.height
    anchor.edges: controller.bottomPanel ? Edges.Top : Edges.Bottom
    anchor.gravity: controller.bottomPanel ? Edges.Top : Edges.Bottom
    anchor.margins.top:controller.bottomPanel?0:metrics.previewTopGap
    anchor.margins.bottom:controller.bottomPanel?metrics.previewTopGap:0
    visible: shown && windows.length > 0
    grabFocus: keyboardOpen
    color: "transparent"
    implicitWidth:pageWindows.length*cardWidth+Math.max(0,pageWindows.length-1)*metrics.previewGap+2*metrics.previewPadding
    implicitHeight:2*metrics.previewPadding+Math.max(26,metrics.previewHeadingSize*1.4)+metrics.previewGap+cardHeight
    GlassCard { anchors.fill: parent; radius: 16; glass: controller.glass; frost: controller.frost; opacity: popup.reveal }
    HoverHandler { onHoveredChanged: if (hovered) popup.pointerEntered(); else popup.pointerLeft() }
    ColumnLayout {
        opacity: popup.reveal
        anchors.fill:parent;anchors.margins:popup.metrics.previewPadding;spacing:popup.metrics.previewGap
        RowLayout {
            Layout.fillWidth: true
            Text { text: popup.application?.name || "Application"; textFormat:Text.PlainText; color: "#dfe9f8"; font.pixelSize:popup.metrics.previewHeadingSize;font.weight:Font.Medium;Layout.fillWidth:true }
            ActionButton { visible: popup.windows.length > popup.capacity; label: "‹"; hint: ""; Accessible.name: "Previous windows"; implicitWidth: 28; implicitHeight: 26; enabled: popup.page > 0; onClicked: popup.page-- }
            ActionButton { visible: popup.windows.length > popup.capacity; label: "›"; hint: ""; Accessible.name: "Next windows"; implicitWidth: 28; implicitHeight: 26; enabled: (popup.page+1)*popup.capacity < popup.windows.length; onClicked: popup.page++ }
        }
        RowLayout {
            spacing:popup.metrics.previewGap
            Repeater {
                id:previewCards
                model: previewRows
                Rectangle {
                    id: card
                    required property string windowAddress
                    readonly property var modelData:popup.pageWindows.find(row=>row.address===windowAddress)||({address:windowAddress,title:"",minimized:false})
                    required property int index
                    property int captureAttempts:0
                    readonly property var captureSource: popup.sourceFor(modelData.address)
                    Layout.preferredWidth:popup.cardWidth;Layout.fillHeight:true
                    radius: 10; color: pointer.containsMouse || activeFocus ? "#283c56" : "#111b29"
                    border.width: activeFocus || modelData.address === popup.controller.windowState.active ? 1 : 0
                    border.color: popup.controller.accent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title || popup.application.name
                    Accessible.onPressAction: popup.windowChosen(modelData)
                    Keys.onReturnPressed: popup.windowChosen(modelData)
                    Keys.onSpacePressed: popup.windowChosen(modelData)
                    Keys.onEscapePressed: popup.dismissed()
                    Component.onCompleted: if (popup.keyboardOpen && index === 0) forceActiveFocus()
                    Loader {
                        id: capture
                        anchors.horizontalCenter:parent.horizontalCenter;y:popup.cardHeaderHeight+6
                        width:popup.captureWidth;height:popup.captureHeight
                        active: popup.captureReady && card.captureSource !== null
                        sourceComponent: ScreencopyView {
                            id: stream
                            captureSource: card.captureSource
                            constraintSize:Qt.size(popup.captureWidth,popup.captureHeight)
                            Component.onCompleted: Qt.callLater(() => {if(popup.visible){card.captureAttempts++;captureFrame();}})
                            live: false; paintCursor: false
                            onHasContentChanged:if(hasContent&&popup.shown&&Quickshell.env("FORYNARCH_PREVIEW_TRACE")==="1")console.debug("PREVIEW_FIRST_FRAME_MS",Date.now()-popup.requestedAt)
                            onCaptureSourceChanged: card.captureAttempts=0
                            Connections {target:popup;function onShownChanged(){if(popup.shown){if(stream.hasContent&&Quickshell.env("FORYNARCH_PREVIEW_TRACE")==="1")console.debug("PREVIEW_CACHE_HIT_MS",Date.now()-popup.requestedAt);card.captureAttempts=0;Qt.callLater(()=>stream.captureFrame());}}}
                            Timer {
                                interval: stream.hasContent ? 300 : card.captureAttempts < 2 ? 60 : 180
                                running: popup.visible && (card.captureAttempts < 3 || (stream.hasContent && controller.previewLive && Quickshell.env("LIBGL_ALWAYS_SOFTWARE") !== "1" && stream.GraphicsInfo.api !== GraphicsInfo.Software))
                                repeat: true
                                onTriggered: {card.captureAttempts++;stream.captureFrame();}
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: capture; spacing: 8; visible: !(capture.item?.hasContent ?? false)
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "grid"; size: 28; ink: "#90a1ba" }
                        Text { text: popup.loading ? "Loading preview…" : card.modelData.minimized ? "Click to restore" : "Preview unavailable"; font.pixelSize: 11; color: "#b5c9e3" }
                    }
                    RowLayout {
                        z:3;anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:4
                        height:popup.cardHeaderHeight-4;spacing:4
                        Text {
                            Layout.fillWidth:true;Layout.leftMargin:4
                            text:card.modelData.title||popup.application.name
                            textFormat:Text.PlainText;elide:Text.ElideRight
                            font.pixelSize:popup.metrics.previewTitleSize;color:"#dfe9f8"
                        }
                        Repeater {
                            model:[
                                {action:card.modelData.minimized?"activate":"minimize",icon:card.modelData.minimized?"restore":"minimize",name:card.modelData.minimized?"Restore window":"Minimize window"},
                                {action:"maximize",icon:card.modelData.fullscreen===1?"restore":"maximize",name:card.modelData.fullscreen===1?"Restore window size":"Maximize window"},
                                {action:"close",icon:"close",name:"Close window"}
                            ]
                            ActionButton {
                                required property var modelData
                                objectName:"preview-action-"+modelData.action+"-"+card.windowAddress
                                icon:modelData.icon;hint:"";showTooltip:false
                                Accessible.name:modelData.name
                                implicitWidth:popup.metrics.previewButtonSize;implicitHeight:popup.metrics.previewButtonSize
                                leftPadding:0;rightPadding:0;rounding:7;quiet:true
                                onClicked:popup.controller.controlWindow(modelData.action,card.modelData.address)
                            }
                        }
                    }
                    MouseArea {
                        id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: popup.windowChosen(card.modelData)
                    }
                }
            }
        }
    }
}
