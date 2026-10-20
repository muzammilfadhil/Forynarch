import QtQuick
import QtQml.Models
import Quickshell

Item {
    id: hotbar
    required property var controller
    required property var panelWindow
    property real maxWidth:220
    readonly property real buttonSize:Math.max(20,Math.min(controller.panelMetrics.appSize,height-8))
    readonly property real iconSize:Math.min(controller.panelMetrics.appIconSize,buttonSize-6)
    readonly property var rawApplications: {
        const groups = [];
        for (const window of controller.windowState.windows) {
            let group = groups.find(item => item.app === window.app);
            if (!group) {
                const entry = DesktopEntries.applications.values.find(entry =>
                    entry.id.toLowerCase().replace(/\.desktop$/, "") === window.app.toLowerCase()
                    || entry.name === window.app
                    || (window.app === "File Manager" && /^(org\.xfce\.)?thunar(\.desktop)?$/i.test(entry.id)));
            group = {app: window.app, name: window.displayName || (window.app === "File Manager" ? "File Manager" : window.app.toLowerCase() === "alacritty" ? "Terminal" : (entry?.name || window.app)),
                icon: window.icon || entry?.icon || "", windows: []};
                groups.push(group);
            }
            group.windows.push({address:window.address,pid:window.pid,title:window.title,minimized:window.minimized,fullscreen:window.fullscreen||0});
        }
        return groups;
    }
    property var applications: []
    ListModel {id:applicationModel}
    function updateApplications() {
        const order = applications.map(app => app.app);
        const rank = app => order.includes(app.app) ? order.indexOf(app.app) : order.length + rawApplications.indexOf(app);
        applications = rawApplications.slice().sort((a,b) => rank(a) - rank(b)).map(app=>{
            const old=applications.find(previous=>previous.app===app.app);
            return old&&JSON.stringify(old)===JSON.stringify(app)?old:app;
        });
        for(let i=applicationModel.count-1;i>=0;i--)if(!applications.some(app=>app.app===applicationModel.get(i).appId))applicationModel.remove(i);
        applications.forEach((app,index)=>{
            if(index<applicationModel.count&&applicationModel.get(index).appId===app.app)return;
            let old=-1;for(let i=index;i<applicationModel.count;i++)if(applicationModel.get(i).appId===app.app){old=i;break;}
            if(old>=0)applicationModel.move(old,index,1);else applicationModel.insert(index,{appId:app.app});
        });
    }
    onRawApplicationsChanged: updateApplications()
    Component.onCompleted: {updateApplications();warmPreview.restart();}
    ListModel {id:previewCaches}
    function cachePreview(app) {
        for(let i=0;i<previewCaches.count;i++)if(previewCaches.get(i).appId===app)return;
        if(previewCaches.count>=3)previewCaches.remove(0);
        previewCaches.append({appId:app});
    }
    readonly property string focusedAddress:controller.windowState.active||""
    onFocusedAddressChanged:warmPreview.restart()
    Timer {id:warmPreview;interval:350;onTriggered:{
        if(hotbar.previewShown)return;
        const group=hotbar.applications.find(app=>app.windows.some(window=>window.address===hotbar.focusedAddress&&!window.minimized));
        if(group)hotbar.cachePreview(group.app);
    }}
    property string pendingApp: ""
    property string previewApp: ""
    property bool previewShown: false
    property double hoverStarted:0
    property real previewX: 0
    property bool keyboardPreview: false
    readonly property var previewGroup: applications.find(app => app.app === previewApp) || null
    implicitWidth:Math.min(maxWidth,applications.length?applications.length*buttonSize+(applications.length-1)*controller.panelMetrics.appSpacing+4:0)
    Behavior on width {enabled:hotbar.controller.motion;NumberAnimation {duration:150;easing.type:Easing.OutCubic}}
    implicitHeight: 40
    visible: applications.length > 0
    onApplicationsChanged: {
        if (previewApp && !applications.some(app => app.app === previewApp)) closePreview();
        for(let i=previewCaches.count-1;i>=0;i--)if(!applications.some(app=>app.app===previewCaches.get(i).appId))previewCaches.remove(i);
        for(const app of applications)if(previewCaches.count<3)cachePreview(app.app);
    }
    function closePreview() { showDelay.stop(); hideDelay.stop(); previewShown = false; pendingApp = ""; }
    function hoverApp(app, item) {
        hoverStarted=Date.now();
        hideDelay.stop(); cachePreview(app); pendingApp = app;
        previewX = item.mapToItem(panelWindow.contentItem, item.width / 2, 0).x;
        keyboardPreview = false;
        if (previewShown) previewApp = app; else showDelay.restart();
    }
    function leave() {showDelay.stop(); hideDelay.restart(); }
    function activate(window) { controller.controlWindow("activate", window.address); closePreview(); }
    Timer { id: showDelay; interval: 110; onTriggered: {hotbar.previewApp = hotbar.pendingApp;hotbar.previewShown=true;if(Quickshell.env("FORYNARCH_PREVIEW_TRACE")==="1")console.debug("PREVIEW_OPEN_MS",Date.now()-hotbar.hoverStarted);} }
    Timer { id: hideDelay; interval: 280; onTriggered: hotbar.closePreview() }
    Flickable {
        id: viewport
        anchors.fill: parent; anchors.margins: 2
        contentWidth: icons.width; contentHeight: height
        clip: true; boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        onContentXChanged: hotbar.closePreview()
        WheelHandler {
            onWheel: event => {
                viewport.contentX = Math.max(0, Math.min(Math.max(0, viewport.contentWidth - viewport.width),
                    viewport.contentX - (event.angleDelta.x || event.angleDelta.y) / 3));
                event.accepted = true;
            }
        }
        Row {
            id: icons
            height:parent.height;spacing:controller.panelMetrics.appSpacing
            Repeater {
                model: applicationModel
                Rectangle {
                    id: appButton
                    required property string appId
                    readonly property var modelData:hotbar.applications.find(app=>app.app===appId)||{app:appId,name:appId,icon:"",windows:[]}
                    readonly property bool focused: modelData.windows.some(w => w.address === hotbar.controller.windowState.active)
                    readonly property bool minimized: modelData.windows.every(w => w.minimized)
                    width:hotbar.buttonSize;height:hotbar.buttonSize;radius:10
                    anchors.verticalCenter:parent.verticalCenter
                    transform:Translate{y:Math.max(-(viewport.height-appButton.height)/2,Math.min((viewport.height-appButton.height)/2,hotbar.controller.panelMetrics.appOffsetY))}
                    Component.onCompleted:if(hotbar.controller.motion)appear.start()
                    ParallelAnimation {id:appear;NumberAnimation {target:appButton;property:"opacity";from:0;to:1;duration:160} NumberAnimation {target:appButton;property:"scale";from:0.86;to:1;duration:180;easing.type:Easing.OutCubic}}
                    color: pointer.containsMouse || activeFocus ? "#293a50" : "transparent"
                    border.width: activeFocus ? 1 : 0; border.color: "#9acbff"
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: open()
                    function open() {
                        if (modelData.windows.length === 1) {
                        const window = modelData.windows[0];
                        if (!window.minimized && window.address === hotbar.controller.windowState.active) {
                            hotbar.controller.controlWindow("minimize",window.address);hotbar.closePreview();
                        } else hotbar.activate(window);
                    }
                        else {
                            hotbar.hoverApp(modelData.app, appButton); hotbar.keyboardPreview = true;
                            showDelay.stop(); hotbar.previewApp = modelData.app;hotbar.previewShown=true;
                        }
                    }
                    Keys.onReturnPressed: open()
                    Keys.onSpacePressed: open()
                    Keys.onEscapePressed: hotbar.closePreview()
                    Behavior on color { enabled: hotbar.controller.motion; ColorAnimation { duration: 100 } }
                    Image {
                        id: appIcon
                        anchors.centerIn:parent
                        width:hotbar.iconSize;height:hotbar.iconSize;sourceSize:Qt.size(32,32)
                        source: appButton.modelData.icon.startsWith("/") ? "file://" + appButton.modelData.icon.split("/").map(encodeURIComponent).join("/") : Quickshell.iconPath(appButton.modelData.icon, true)
                        opacity: appButton.minimized ? 0.55 : 1; fillMode: Image.PreserveAspectFit
                        scale:pointer.pressed?0.92:pointer.containsMouse?1.1:1
                        Behavior on scale {enabled:hotbar.controller.motion;NumberAnimation {duration:130;easing.type:Easing.OutCubic}}
                    }
                    Text {
                        anchors.centerIn: appIcon
                        text: appButton.modelData.name.trim().split(/\s+/).map(word=>word[0]).slice(0,2).join("").toUpperCase()
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        color: "#9acbff"; opacity: appButton.minimized ? 0.55 : 1
                        visible: appIcon.status === Image.Error || appIcon.status === Image.Null
                    }
                    Rectangle {
                        anchors.horizontalCenter:parent.horizontalCenter;y:Math.min(parent.height-3,parent.height/2+hotbar.iconSize/2+hotbar.controller.panelMetrics.indicatorGap)
                        width: appButton.focused ? 12 : 4; height: 3; radius: 1.5
                        Behavior on width {enabled:hotbar.controller.motion;NumberAnimation {duration:140;easing.type:Easing.OutCubic}}
                        color: appButton.focused ? hotbar.controller.accent : "#90a1ba"
                        opacity: appButton.minimized ? 0.45 : 1
                    }
                    MouseArea {
                        id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: hotbar.hoverApp(appButton.modelData.app, appButton)
                        onExited: hotbar.leave()
                        onClicked: appButton.open()
                    }
                }
            }
        }
    }
    Instantiator {
        model:previewCaches
        delegate: WindowPreviews {
            required property string appId
            shown: hotbar.previewShown && hotbar.previewApp===appId && !controller.launcherOpen && !controller.settingsOpen && !controller.controlOpen && !controller.layoutOpen && !controller.trayOpen && !controller.notificationsOpen
            controller: hotbar.controller
            panelWindow: hotbar.panelWindow
            application: hotbar.applications.find(app=>app.app===appId)||null
            anchorX: hotbar.previewX
            keyboardOpen: hotbar.keyboardPreview
            requestedAt:hotbar.hoverStarted
            onDismissed: hotbar.closePreview()
            onPointerEntered: hideDelay.stop()
            onPointerLeft: hotbar.leave()
            onWindowChosen: window => hotbar.activate(window)
        }
    }
}
