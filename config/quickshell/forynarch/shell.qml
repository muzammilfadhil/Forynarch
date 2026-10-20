//@ pragma UseQApplication
//@ pragma DefaultEnv QT_QPA_PLATFORMTHEME = gtk3
//@ pragma DefaultEnv GTK_THEME = Adwaita:dark
//@ pragma IconTheme Forynarch
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "SettingsCatalog.js" as Catalog
import "WidgetLayout.js" as WidgetLayout
import "WidgetPacks.js" as Packs
import "ControlCenterLayout.js" as Controls
import "PanelMetrics.js" as Metrics

ShellRoot {
    id: desktop
    property string defaultTerminal: "Alacritty.desktop"
    CaptureModel {id:capture;controller:desktop}
    readonly property var audioRouter:routing
    AudioRouter {id:routing;active:(desktop.controlOpen&&(desktop.controlAudioRequested||desktop.controlCenterStyle==="classic"))||(desktop.settingsOpen&&desktop.settingsPage==="Sound")}
    property string panelStyle:"classic"
    property var panelMetrics:Metrics.defaults()
    property real panelActualHeight:44
    readonly property real panelReserved:panelActualHeight+(panelStyle==="macshell"?0:panelMetrics.topMargin)
    function setPanelMetric(key,value){const next=Metrics.update(panelMetrics,key,value);if(next!==null){panelMetrics=next;save();}}
    function resetPanelMetrics(){panelMetrics=Metrics.defaults();save();}
    property string controlCenterStyle:"classic"
    property string controlCenterSurface:"tiles"
    property bool controlAudioRequested:false
    property var controlCenterControls:Controls.defaults.slice()
    function setComponentStyle(key,value){if(!["panelStyle","controlCenterStyle"].includes(key)||!["classic","macshell"].includes(value))return;desktop[key]=value;save();}
    function setPanelStyle(value){setComponentStyle("panelStyle",value);}
    function setControlCenterSurface(value){if(!["tiles","panel"].includes(value))return;controlCenterSurface=value;save();}
    function setControlCenterControls(value){controlCenterControls=Controls.valid(value);save();}
    QuickControlActions {id:quickActions;controller:desktop}
    readonly property var quickControlActions:quickActions
    property string musicStyle:"macshell"
    property string musicPlayer:"auto"
    property bool musicArtwork:true
    property bool musicLyrics:false
    property bool musicCava:true
    MediaModel {id:mediaData;controller:desktop}
    readonly property var mediaModel:mediaData
    function setMusic(key,value){
        if(key==="musicStyle"){if(!["classic","macshell"].includes(value))return;}
        else if(key==="musicPlayer"){if(typeof value!=="string"||value.length>256||(!["auto","mudilmusic"].includes(value)&&!/^org\.mpris\.MediaPlayer2\.[A-Za-z0-9_.-]+$/.test(value)))return;}
        else if(!["musicArtwork","musicLyrics","musicCava"].includes(key)||typeof value!=="boolean")return;
        desktop[key]=value;save();
    }

    readonly property var captureModel:capture
    property bool captureOpen:false
    property bool clipboardOpen:false
    function openScreenshots(){clearPopups();capture.refresh();captureOpen=true;}
    function openClipboard(){clearPopups();capture.refresh();clipboardOpen=true;}

    function refreshDefaultApps() { if (!defaultAppsStatus.running) defaultAppsStatus.running = true; }
    onLauncherOpenChanged: if (launcherOpen) refreshDefaultApps()
    Process {
        id: defaultAppsStatus; command: ["forynarch-default-apps", "terminal"]; running: true
        stdout: StdioCollector { onStreamFinished: { try { desktop.defaultTerminal = JSON.parse(text).terminal; } catch (e) {} } }
    }
    property bool launcherOpen: false
    property bool welcomeOpen: false
    Process {
        command: ["bash", "-c", "[[ -d /run/archiso && -n ${XDG_RUNTIME_DIR:-} ]] && mkdir -- \"$XDG_RUNTIME_DIR/forynarch-welcome-shown\""]
        running: true
        onExited: (exitCode, exitStatus) => { if (exitCode === 0) desktop.welcomeOpen = true; }
    }
    property bool emojiOpen: false
    property bool webAppsOpen:false
    property bool layoutOpen: false
    property string layoutWindow: ""
    property bool layoutRequested: false
    property string lastFocusedWindow: ""
    onWindowStateChanged: if (windowState.windows.some(window => window.address === windowState.active)) lastFocusedWindow = windowState.active
    onLayoutOpenChanged: if (!layoutOpen) requestFocusReturn()
    function openLayout() { layoutRequested = true; refreshWindows(); }
    function requestFocusReturn(){focusReturn.restart();}
    onEmojiOpenChanged:if(!emojiOpen)requestFocusReturn()
    Timer {id:focusReturn;interval:40;onTriggered:if(!desktop.batteryOpen&&!desktop.settingsOpen&&!desktop.controlOpen&&!desktop.launcherOpen&&!desktop.drivesOpen&&!desktop.emojiOpen&&!desktop.webAppsOpen&&!desktop.layoutOpen&&!desktop.widgetPacksOpen&&!desktop.desktopShortcutsOpen&&!desktop.welcomeOpen&&!desktop.widgetEditing)desktop.run(["forynarch-hotkey","focus-return"])}
    property bool emojiClosing: false
    property bool drivesOpen: false
    property bool drivesClosing: false
    property bool settingsClosing: false
    property bool controlsClosing: false
    property bool launcherClosing: false
    property bool motion: true
    property bool motionBlur: true
    property bool widgetClock: true
    property bool widgetCalendar: true
    property bool widgetGreeting: true
    property bool widgetMedia: true
    property bool widgetsRight: false
    property real widgetScale: 1
    property var widgetOrder: ["clock","calendar","greeting","media"]
    property var widgetPositions: ({})
    property var widgetExtras: ({})
    property bool widgetPacksOpen: false
    property bool desktopShortcutsEnabled: false
    property bool desktopShortcutsOpen: false
    property var desktopShortcutIds: []
    readonly property var desktopShortcutEntries: desktopShortcutIds.map(id=>DesktopEntries.applications.values.find(entry=>entry.id===id)).filter(entry=>!!entry)
    function openDesktopShortcuts() {clearPopups();desktopShortcutsOpen=true;}
    function setDesktopShortcut(id,enabled) {
        if(!DesktopEntries.applications.values.some(entry=>entry.id===id))return;
        if(enabled&&!desktopShortcutIds.includes(id)&&desktopShortcutIds.length<32)desktopShortcutIds=desktopShortcutIds.concat([id]);
        else if(!enabled)desktopShortcutIds=desktopShortcutIds.filter(value=>value!==id);
        save();
    }
    function launchDesktopShortcut(entry) {
        if(!entry?.command?.length)return;
        Quickshell.execDetached({command:entry.runInTerminal?["forynarch-terminal","--"].concat(entry.command):entry.command,workingDirectory:entry.workingDirectory||Quickshell.env("HOME")});
    }
    onWidgetPacksOpenChanged:if(!widgetPacksOpen)requestFocusReturn()
    property var importedPacks: []
    property var packWarnings: []
    property string packFolder: ""
    readonly property var customWidgets: {
        const result=[];
        importedPacks.forEach(pack=>pack.widgets.forEach(widget=>result.push(Object.assign({},widget,{key:"custom:"+pack.id+":"+widget.id,packName:pack.name}))));
        return result;
    }
    readonly property var widgetKeys: WidgetLayout.keys.concat(customWidgets.map(row=>row.key))
    readonly property var widgetCatalog: Packs.widgets.concat(customWidgets.map(row=>({id:row.key,label:row.name})))
    readonly property var customWidgetHeights: {const result={media:musicLyrics?(musicStyle==="macshell"?190:246):130};customWidgets.forEach(row=>result[row.key]=row.height);return result;}
    readonly property bool customNeedsMetrics: customWidgets.some(row=>widgetEnabled(row.key)&&row.items.some(item=>item.kind==="meter"||/\{(memoryUsed|memoryTotal|batteryPercent)\}/.test(item.text||"")))
    function reloadWidgetPacks() {if(!packCatalog.running)packCatalog.running=true;}
    function openWidgetPacks() {if(widgetEditing)finishWidgetEdit(true);clearPopups();widgetPacksOpen=true;}
    Process {
        id: packCatalog; command:["forynarch-widget-packs","list"]; running:true
        stdout:StdioCollector {onStreamFinished:{try{
            const result=JSON.parse(text);desktop.importedPacks=result.packs;desktop.packWarnings=result.warnings;desktop.packFolder=result.folder;
            desktop.widgetOrder=desktop.widgetOrder.filter(key=>desktop.widgetKeys.includes(key)).concat(desktop.widgetKeys.filter(key=>!desktop.widgetOrder.includes(key)));
        }catch(error){console.warn("Widget pack catalog could not be read.");}}}
    }
    property var widgetMetrics: ({capacity:-1})
    property string windowMode:"dwindle"
    property string floatingSize:"comfortable"
    property var windowState:({active:"",windows:[]})
    property var shortcutRows:[]
    function refreshShortcutLabels(){if(!shortcutLabels.running)shortcutLabels.running=true;}
    function shortcutLabel(title,fallback){const row=shortcutRows.find(r=>r.title===title);return row?(row.keys||"Unassigned"):fallback;}
    Process {id:shortcutLabels;command:["forynarch-shortcut-config","status"];running:true
        stdout:StdioCollector{onStreamFinished:{try{desktop.shortcutRows=JSON.parse(text).rows;}catch(e){}}}
    }
    property var snapPreview:({monitor:"",region:""})
    property var snapMonitors:[]
    property var snapStyle:({windowGap:6,screenMargin:14,cornerRadius:10})
    Process {id:snapStyleQuery;command:["forynarch-system","preferences"]
        stdout:StdioCollector{onStreamFinished:{try{desktop.snapStyle=JSON.parse(text);}catch(e){}}}}
    Process {id:snapMonitorQuery;command:["hyprctl","-j","monitors"]
        stdout:StdioCollector{onStreamFinished:{try{desktop.snapMonitors=JSON.parse(text);}catch(e){}}}}
    function handleSnap(data) {
        const values=data.split(",");if(values[0]!=="forynarch-snap")return;
        if(values[1]==="clear"){snapPreview={monitor:"",region:""};return;}
        if(!autoSnap||values.length!==5||!/^0x[0-9a-f]+$/i.test(values[2])||!["left","right","top","bottom","top-left","top-right","bottom-left","bottom-right","maximize"].includes(values[4]))return;
        if(values[1]==="preview"||values[1]==="preview-top"){
            if(snapPreview.monitor!==values[3]){
                if(!snapMonitorQuery.running)snapMonitorQuery.running=true;
                if(!snapStyleQuery.running)snapStyleQuery.running=true;
            }
            snapPreview={monitor:values[3],region:values[4],choices:values[1]==="preview-top"};return;
        }
        if(values[1]!=="apply")return;
        snapPreview={monitor:"",region:""};
        if(values[4]==="maximize"){controlWindow("maximize",values[2]);return;}
        if(!snapAction.running){snapAction.command=["forynarch-window-layout","snap-"+values[4],values[2]];snapAction.running=true;}
    }
    Process {id:snapAction;onExited:desktop.refreshWindows()}
    property string windowError:""
    readonly property bool windowActionBusy:windowAction.running
    property bool windowRefreshPending:false
    function refreshWindows(){windowRefresh.restart();}
    function controlWindow(action,address){if(windowAction.running)return;windowError="";windowAction.command=["forynarch-window-control",action].concat(address?[address]:[]);windowAction.running=true;}
    Timer {id:windowRefresh;interval:70;onTriggered:{if(windowStatus.running)desktop.windowRefreshPending=true;else windowStatus.running=true;}}
    Process {id:windowStatus;command:["forynarch-window-control","status"];running:true
        stdout:StdioCollector{onStreamFinished:{try{
            const state = JSON.parse(text);
            desktop.windowState = state;
            if (desktop.layoutRequested && state.workspace === desktop.workspaceId) {
                desktop.layoutRequested = false;
                const available = state.windows.filter(window => !window.minimized);
                desktop.layoutWindow = available.find(window => window.address === state.active)?.address
                    || available.find(window => window.address === desktop.lastFocusedWindow)?.address
                    || available[0]?.address || "";
                desktop.clearPopups(); desktop.layoutOpen = true;
            }
        }catch(e){}}}
        onExited:(exitCode,exitStatus)=>{if(exitCode!==0)desktop.layoutRequested=false;if(desktop.windowRefreshPending||desktop.layoutRequested){desktop.windowRefreshPending=false;desktop.refreshWindows();}}
    }
    Process {id:windowAction
        stderr:StdioCollector{onStreamFinished:desktop.windowError=text.trim()}
        onExited:(code,status)=>{if(code!==0&&desktop.windowError)desktop.run(["notify-send","Window action",desktop.windowError]);desktop.refreshWindows();}
    }
    Connections {target:Hyprland;function onRawEvent(event){
        if(event.name==="minimized"){
            const parts=event.data.split(",");
            if(/^[0-9a-fA-F]+$/.test(parts[0])&&["0","1"].includes(parts[1]))desktop.controlWindow(parts[1]==="1"?"minimize":"restore","0x"+parts[0]);
            return;
        }
        if(event.name==="custom"&&event.data.startsWith("forynarch-snap,")){desktop.handleSnap(event.data);return;}
        if(event.name==="activewindowv2"){
            let address=event.data.trim();if(address&&!address.startsWith("0x"))address="0x"+address;
            if(!address||address==="0x0"||desktop.windowState.windows.some(window=>window.address===address))
                desktop.windowState=Object.assign({},desktop.windowState,{active:address});
            else desktop.refreshWindows();
            return;
        }
        if(["openwindow","closewindow","movewindow","movewindowv2","fullscreen","changefloatingmode","workspace","workspacev2"].includes(event.name))desktop.refreshWindows();
    }}
    onWindowModeChanged:refreshWindows()
    property bool applyModeToOpen:false
    readonly property int workspaceId:Hyprland.focusedMonitor?.activeWorkspace?.id??1
    onWorkspaceIdChanged:if(!windowModeStatus.running)windowModeStatus.running=true
    Process {id:windowModeStatus;command:["forynarch-window-mode","status"];running:true;stdout:StdioCollector{onStreamFinished:{try{const state=JSON.parse(text);desktop.windowMode=state.mode;desktop.floatingSize=state.size||"comfortable";}catch(e){}}}}
    property var cavaValues:[]
    Process {
        id:cavaProcess
        command:["cava","-p","/usr/share/forynarch/cava.conf"]
        running:desktop.widgets&&desktop.widgetMedia&&desktop.musicStyle==="classic"&&desktop.musicCava&&!desktop.widgetEditing&&desktop.motion&&(desktop.player?.isPlaying??false)
        stdout:SplitParser {onRead:data=>{desktop.cavaValues=data.split(";").slice(0,16).map(value=>Math.max(0,Math.min(100,Number(value)||0)));}}
        onRunningChanged:if(!running)desktop.cavaValues=[]
    }
    property int focusRemaining:1500
    property bool focusRunning:false
    property double focusDeadline:0
    onFocusRunningChanged:if(focusRunning)focusDeadline=Date.now()+focusRemaining*1000
    Timer {interval:1000;running:desktop.focusRunning;repeat:true;onTriggered:{desktop.focusRemaining=Math.max(0,Math.ceil((desktop.focusDeadline-Date.now())/1000));if(desktop.focusRemaining===0){desktop.focusRunning=false;desktop.run(["notify-send","Focus complete","Take a short break."]);}}}
    Process {id:metrics;command:["forynarch-widget-metrics"];stdout:StdioCollector{onStreamFinished:{try{desktop.widgetMetrics=JSON.parse(text);}catch(e){}}}}
    Timer {interval:30000;running:desktop.widgets&&!!(desktop.widgetExtras.system||desktop.widgetExtras.battery||desktop.customNeedsMetrics);repeat:true;triggeredOnStart:true;onTriggered:if(!metrics.running)metrics.running=true}
    property bool updatingPack:false
    function applyWidgetPack(id) {
        var pack=Packs.packs.find(row=>row.id===id);if(!pack)return;
        updatingPack=true;
        widgetKeys.forEach(key=>setWidget(key,pack.keys.includes(key)));
        widgetOrder=pack.keys.concat(widgetKeys.filter(key=>!pack.keys.includes(key)));
        widgetPositions={};widgets=true;updatingPack=false;save();
    }
    property bool widgetEditing: false
    property bool widgetSnap: true
    property bool widgetGrid: true
    property string widgetSnapshot: ""
    function editWidgets() {
        widgetSnapshot=JSON.stringify({positions:widgetPositions,extras:widgetExtras,order:widgetOrder,flags:[widgetClock,widgetCalendar,widgetGreeting,widgetMedia],enabled:widgets,scale:widgetScale,snap:widgetSnap,grid:widgetGrid});
        clearPopups();widgets=true;widgetEditing=true;
    }
    function finishWidgetEdit(commit) {
        if(!widgetEditing)return;
        if(!commit){var old=JSON.parse(widgetSnapshot);widgetPositions=old.positions;widgetExtras=old.extras;widgetOrder=old.order;widgetClock=old.flags[0];widgetCalendar=old.flags[1];widgetGreeting=old.flags[2];widgetMedia=old.flags[3];widgets=old.enabled;widgetScale=old.scale;widgetSnap=old.snap;widgetGrid=old.grid;}
        widgetEditing=false;widgetSnapshot="";if(commit)save();
    }
    function placeWidget(output,key,x,y,w,h,scale) {widgetPositions=WidgetLayout.moved(widgetPositions,output,key,x,y,w,h,scale,widgetSnap,customWidgetHeights);}
    function widgetPreset(output,name,w,h,scale) {widgetPositions=WidgetLayout.preset(widgetPositions,output,name,w,h,scale,widgetOrder.filter(key=>widgetKeys.includes(key)&&widgetEnabled(key)),customWidgetHeights);}
    property bool settingsOpen: false
    property bool controlOpen: false
    property string settingsPage: "Appearance"
    property bool glass: true
    property bool applicationGlass: true
    property int applicationOpacity: 84
    property bool widgets: true
    property bool panelCompact: false
    property int panelSpacing: 12
    property bool panelShowApps: true
    property bool panelShowClock: true
    property bool panelShowWorkspaces: true
    property bool panelShowMode: true
    property bool panelShowNetwork: true
property bool panelShowLauncher: true
property bool panelShowTray: true
property bool panelShowNotifications: true
property bool panelShowAudio: true
property bool panelShowControls: true
property bool panelShowBattery: true
property bool panelShowSettings: true
    property bool panelShowPower: true
    property bool panelShowDesktop: true
    property bool previewLive: true
    property bool autoSnap: true
    property bool islands: true
    property bool bottomPanel: false
    property bool clock12: false
    property string accent: "#9acbff"
    property int frost: 4
    property date now: new Date()
    readonly property int workspace: ((Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1)-1)%5+1
    readonly property var player:mediaData.player
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var microphone: Pipewire.defaultAudioSource?.audio ?? null
    readonly property string timeText: Qt.formatDateTime(now, clock12 ? "h:mm AP" : "HH:mm")
    readonly property string userName: Quickshell.env("USER") || "User"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/forynarch/appearance.json"
    function run(command) { Quickshell.execDetached(command); }
    function dismissSettings() { settingsClosing=motion && settingsOpen; settingsOpen=false; if(settingsClosing) settingsClose.restart();requestFocusReturn(); }
    function dismissControls() { controlsClosing=motion && controlOpen; controlOpen=false; if(controlsClosing) controlsClose.restart();requestFocusReturn(); }
    function dismissLauncher() { launcherClosing=motion && launcherOpen; launcherOpen=false; if(launcherClosing) launcherClose.restart();requestFocusReturn(); }
    function dismissDrives() { drivesClosing=motion && drivesOpen; drivesOpen=false; if(drivesClosing) drivesClose.restart();requestFocusReturn(); }
    property bool batteryOpen:false
readonly property var batteryStatus:batteryModel.snapshot
readonly property string batteryError:batteryModel.error
BatteryModel {id:batteryModel;controller:desktop}
function openBattery(){const opened=batteryOpen;clearPopups();batteryOpen=!opened;}
function dismissBattery(){batteryOpen=false;requestFocusReturn();}
property bool trayOpen:false
    property bool notificationsOpen:false
    property bool notificationsDnd:false
    property int notificationCount:0
    function openNotifications(){let opened=notificationsOpen;clearPopups();notificationsOpen=!opened;notificationCount=0;}
    Process {id:notificationInitial;command:["forynarch-notifications","status"];stdout:StdioCollector {onStreamFinished:{try{desktop.notificationsDnd=JSON.parse(text).dnd;}catch(e){}}}}
    Timer {interval:2000;running:true;onTriggered:notificationInitial.running=true}
    function clearPopups() { batteryOpen=false;captureOpen=false;clipboardOpen=false; trayOpen=false;notificationsOpen=false; desktopShortcutsOpen=false;widgetPacksOpen=false;layoutOpen=false;webAppsOpen=false;emojiClose.stop();emojiOpen=false;emojiClosing=false;settingsClose.stop(); controlsClose.stop(); launcherClose.stop(); drivesClose.stop(); settingsClosing=false; controlsClosing=false; launcherClosing=false; drivesClosing=false; settingsOpen=false; controlOpen=false; launcherOpen=false; drivesOpen=false; }
    function openSettings(page) { clearPopups(); settingsPage=page || "Appearance"; settingsOpen=true; }
    function openControls() { clearPopups();controlAudioRequested=false;controlOpen=true; }
    function openAdvancedAudio(){const opened=controlOpen&&controlAudioRequested;clearPopups();if(!opened){controlAudioRequested=true;controlOpen=true;}}
    function openLauncher() { clearPopups(); launcherOpen=true; }
    function openEmoji() { clearPopups(); emojiOpen=true; }
    function openWebApps() { clearPopups();webAppsOpen=true; }
    function closeEmoji() { emojiOpen=false; emojiClosing=true; emojiClose.restart(); }
    function openDrives() { clearPopups(); drivesOpen=true; }
    function widgetEnabled(key) { return ({clock:widgetClock,calendar:widgetCalendar,greeting:widgetGreeting,media:widgetMedia}[key] ?? widgetExtras[key]) === true; }
    function setWidget(key,value) { if(!widgetKeys.includes(key))return;const property={clock:"widgetClock",calendar:"widgetCalendar",greeting:"widgetGreeting",media:"widgetMedia"}[key];if(property)desktop[property]=value;else{var next=Object.assign({},widgetExtras);next[key]=value;widgetExtras=next;if(!widgetOrder.includes(key))widgetOrder=widgetOrder.concat([key]);}save(); }
    function moveWidget(key,delta) { const order=widgetOrder.slice(), index=order.indexOf(key), next=index+delta; if(index>=0 && next>=0 && next<order.length) { order.splice(index,1); order.splice(next,0,key); widgetOrder=order; save(); } }
    function setWidgetsRight(value) { widgetsRight=value; save(); }
    function setWidgetScale(value) { if([0.8,1,1.2].indexOf(value)>=0) {widgetScale=value;save();} }
    function setMotion(value) { motion=value; run(["forynarch-motion",value?"on":"off"]); save(); }
    function setMotionBlur(value) { motionBlur=value; save(); }
    function save() {
        if(widgetEditing||updatingPack)return;
        state.setText(JSON.stringify({componentStylesVersion:1,panelStyle:panelStyle,panelMetrics:panelMetrics,controlCenterStyle:controlCenterStyle,controlCenterSurface:controlCenterSurface,controlCenterControls:controlCenterControls,musicStyle:musicStyle,musicPlayer:musicPlayer,musicArtwork:musicArtwork,musicLyrics:musicLyrics,musicCava:musicCava,desktopShortcutsEnabled:desktopShortcutsEnabled,desktopShortcutIds:desktopShortcutIds,glass:glass, applicationGlass:applicationGlass, applicationOpacity:applicationOpacity, widgets:widgets, accent:accent, frost:frost,
            panelShowLauncher:panelShowLauncher,panelShowTray:panelShowTray,panelShowNotifications:panelShowNotifications,panelShowAudio:panelShowAudio,panelShowControls:panelShowControls,panelShowBattery:panelShowBattery,panelShowSettings:panelShowSettings,
panelCompact:panelCompact,panelSpacing:panelSpacing,panelShowApps:panelShowApps,panelShowClock:panelShowClock,panelShowWorkspaces:panelShowWorkspaces,
            panelShowMode:panelShowMode,panelShowNetwork:panelShowNetwork,panelShowPower:panelShowPower,panelShowDesktop:panelShowDesktop,previewLive:previewLive,autoSnap:autoSnap,
            islands:islands, bottomPanel:bottomPanel, clock12:clock12, motion:motion, motionBlur:motionBlur,
            widgetClock:widgetClock,widgetCalendar:widgetCalendar,widgetGreeting:widgetGreeting,widgetMedia:widgetMedia,
            widgetsRight:widgetsRight,widgetScale:widgetScale,widgetOrder:widgetOrder,widgetPositions:widgetPositions,widgetExtras:widgetExtras,widgetSnap:widgetSnap,widgetGrid:widgetGrid}));
    }
    function applyBlur() {
        run(["hyprctl", "eval", "hl.config({decoration={blur={enabled=" + (glass ? "true" : "false") + ",size=" + frost + ",passes=2}}})"]);
        run(["forynarch-application-theme",glass && applicationGlass ? "on" : "off",String(applicationOpacity)]);
    }
    function restoreEffects() {
        applyBlur();
        run(["forynarch-motion","restore"]);
        run(["hyprctl","eval","_G.forynarch_snap_enabled="+(autoSnap?"true":"false")]);
        run(["hyprctl","eval",'hl.layer_rule({name="forynarch-glass",match={namespace="^forynarch-(panel|widgets|widget-editor|settings|controls|dock|launcher|drives|emoji|webapps|live-welcome|widget-packs|window-layout|desktop-shortcuts|capture|clipboard|battery)$"},blur=true,blur_popups=true,xray=false,ignore_alpha=0.2,no_anim=true})']);
    }
    function setApplicationGlass(value) { applicationGlass=value; applyBlur(); save(); }
    function setApplicationOpacity(value) { if([76,84,92].indexOf(value)<0) return; applicationOpacity=value; applyBlur(); save(); }
    function setGlass(value) { glass = value; applyBlur(); save(); }
    function setAccent(value) { if (["#9acbff","#a5b8ed","#9bcbd1","#76c0ec"].indexOf(value) >= 0) { accent = value; save(); } }
    function setFrost(value) { if ([2,4,6].indexOf(value) >= 0) { frost = value; applyBlur(); save(); } }
    function setWidgets(value) { widgets = value; save(); }
    function setIslands(value) { islands = value; save(); }
    function setBottomPanel(value) { bottomPanel = value; save(); }
    function setPanel(key,value) {
        if (key === "panelSpacing") { if (![8,12,18,24].includes(value)) return; }
        else if (!["panelShowLauncher","panelShowTray","panelShowNotifications","panelShowAudio","panelShowControls","panelShowBattery","panelShowSettings","panelCompact","panelShowApps","panelShowClock","panelShowWorkspaces","panelShowMode","panelShowNetwork","panelShowPower","panelShowDesktop","previewLive","autoSnap"].includes(key) || typeof value !== "boolean") return;
        desktop[key]=value;
        if (key === "autoSnap") run(["hyprctl","eval","_G.forynarch_snap_enabled="+(value?"true":"false")]);
        save();
    }
    function setClock12(value) { clock12 = value; save(); }
    function setVolume(value) { if (audio) audio.volume = Math.max(0, Math.min(1, value)); }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink,Pipewire.defaultAudioSource] }
    FileView {
        id: state; path: desktop.statePath; printErrors: false
        onLoaded: {
            try {
                const v = JSON.parse(text());
            desktop.panelMetrics=Metrics.valid(v.panelMetrics);
            if(["classic","macshell"].includes(v.panelStyle))desktop.panelStyle=v.panelStyle;
            if(["classic","macshell"].includes(v.controlCenterStyle))desktop.controlCenterStyle=v.controlCenterStyle;
            else if(v.componentStylesVersion===undefined&&["classic","macshell"].includes(v.panelStyle))desktop.controlCenterStyle=v.panelStyle;
            if(["tiles","panel"].includes(v.controlCenterSurface))desktop.controlCenterSurface=v.controlCenterSurface;
            desktop.controlCenterControls=Controls.valid(v.controlCenterControls);
            if(["classic","macshell"].includes(v.musicStyle))desktop.musicStyle=v.musicStyle;
            if(typeof v.musicPlayer==="string"&&v.musicPlayer.length<=256&&(["auto","mudilmusic"].includes(v.musicPlayer)||/^org\.mpris\.MediaPlayer2\.[A-Za-z0-9_.-]+$/.test(v.musicPlayer)))desktop.musicPlayer=v.musicPlayer;
            for(let key of ["musicArtwork","musicLyrics","musicCava"])if(typeof v[key]==="boolean")desktop[key]=v[key];

                for (let key of ["panelShowLauncher","panelShowTray","panelShowNotifications","panelShowAudio","panelShowControls","panelShowBattery","panelShowSettings","panelCompact","panelShowApps","panelShowClock","panelShowWorkspaces","panelShowMode","panelShowNetwork","panelShowPower","panelShowDesktop","previewLive","autoSnap","glass","applicationGlass","widgets","islands","bottomPanel","clock12","motion","motionBlur","widgetClock","widgetCalendar","widgetGreeting","widgetMedia","widgetsRight","desktopShortcutsEnabled"])
                    if (typeof v[key] === "boolean") desktop[key] = v[key];
                if ([8,12,18,24].includes(v.panelSpacing)) desktop.panelSpacing=v.panelSpacing;
                if (["#9acbff","#a5b8ed","#9bcbd1","#76c0ec"].indexOf(v.accent) >= 0) desktop.accent = v.accent;
                if ([2,4,6].indexOf(v.frost) >= 0) desktop.frost = v.frost;
                if ([76,84,92].indexOf(v.applicationOpacity)>=0) desktop.applicationOpacity=v.applicationOpacity;
                if([0.8,1,1.2].indexOf(v.widgetScale)>=0) desktop.widgetScale=v.widgetScale;
            if(Array.isArray(v.desktopShortcutIds))desktop.desktopShortcutIds=[...new Set(v.desktopShortcutIds.filter(id=>typeof id==="string"&&id.length>0&&id.length<=256))].slice(0,32);
                desktop.widgetPositions=WidgetLayout.valid(v.widgetPositions);
            if(typeof v.widgetSnap==="boolean")desktop.widgetSnap=v.widgetSnap;
            if(typeof v.widgetGrid==="boolean")desktop.widgetGrid=v.widgetGrid;
                desktop.widgetExtras=Packs.extras(v.widgetExtras);
                if(Array.isArray(v.widgetOrder)){var order=[...new Set(v.widgetOrder.filter(key=>WidgetLayout.keys.includes(key)||WidgetLayout.custom(key)).slice(0,34))];desktop.widgetOrder=order.concat(desktop.widgetKeys.filter(key=>!order.includes(key)));}
                desktop.restoreEffects();
            } catch (error) { console.warn("Appearance preferences could not be read."); }
        }
    }
    Component.onCompleted: {
        Application.styleHints.colorScheme=Qt.ColorScheme.Dark;
        desktop.restoreEffects();
    }
    Timer { interval: Math.max(1,60-desktop.now.getSeconds())*1000; running: true; repeat: true; onTriggered: desktop.now = new Date() }
    Timer { id: settingsClose; interval: 180; onTriggered: desktop.settingsClosing=false }
    Timer { id: controlsClose; interval: 180; onTriggered: desktop.controlsClosing=false }
    Timer { id: launcherClose; interval: 180; onTriggered: desktop.launcherClosing=false }
    Timer { id: emojiClose; interval: 200; onTriggered: desktop.emojiClosing=false }
    Timer { id: drivesClose; interval: 180; onTriggered: desktop.drivesClosing=false }
    IpcHandler {
        target: "appearance"
        function openBattery():void {desktop.openBattery();}
        function openScreenshots():void {desktop.openScreenshots();}
        function openClipboard():void {desktop.openClipboard();}
        function closePopups():void {desktop.clearPopups();desktop.requestFocusReturn();}
        function setPanelStyle(style:string):void {desktop.setPanelStyle(style);}
          function setPanelMetric(key:string,value:int):void {desktop.setPanelMetric(key,value);}
          function resetPanelMetrics():void {desktop.resetPanelMetrics();}
          function openAdvancedAudio():void {desktop.openAdvancedAudio();}
        function setComponentStyle(key:string,style:string):void {desktop.setComponentStyle(key,style);}
        function setControlCenterSurface(style:string):void {desktop.setControlCenterSurface(style);}
        function controlCenterStatus():string {return JSON.stringify({metrics:desktop.panelMetrics,bar:desktop.panelStyle,controlCenter:desktop.controlCenterStyle,surface:desktop.controlCenterSurface,music:desktop.musicStyle,controls:desktop.controlCenterControls,layout:Controls.layout(desktop.controlCenterControls),open:desktop.controlOpen,glass:controlsLoader.item?.glassStatus??null,awake:quickActions.keepAwake,nightLight:quickActions.nightLight,error:quickActions.error});}
        function setControlCenterControls(ids:string):void {try{desktop.setControlCenterControls(JSON.parse(ids));}catch(e){}}
        function setMusic(key:string,value:string):void {desktop.setMusic(key,["musicArtwork","musicLyrics","musicCava"].includes(key)?value==="true":value);}
        function mediaStatus():string {return JSON.stringify({panelStyle:desktop.panelStyle,musicStyle:desktop.musicStyle,player:desktop.player?.identity??"",title:desktop.player?.trackTitle??"",playing:desktop.player?.isPlaying??false,artwork:desktop.musicArtwork,lyrics:desktop.musicLyrics,lyricsState:mediaData.state,lyricLines:mediaData.lines.length,cavaRunning:cavaProcess.running,controlGlass:controlsLoader.item?.glassStatus??null});}
        function restoreEffects():void {desktop.restoreEffects();}
        function windows():string {return JSON.stringify(desktop.windowState);}
        function windowControl(action:string,address:string):void {desktop.controlWindow(action,address);}
        function openLayout():void {desktop.openLayout();}
        function openWidgetPacks():void {desktop.openWidgetPacks();}
        function openDesktopShortcuts():void {desktop.openDesktopShortcuts();}

        function toggleSettings(): void { if(desktop.settingsOpen) desktop.dismissSettings(); else desktop.openSettings("Appearance"); }
        function openSettings(): void { desktop.openSettings("Appearance"); }
        function notificationMode(value:bool): void {desktop.notificationsDnd=value;}
        function openNotifications(): void {desktop.openNotifications();}
        function openBackgroundApps(): void {let opened=desktop.trayOpen;desktop.clearPopups();desktop.trayOpen=!opened;}
        function notificationReceived(): void {if(!desktop.notificationsOpen)desktop.notificationCount=Math.min(99,desktop.notificationCount+1);}
        function closeSettings(): void { desktop.trayOpen=false;desktop.notificationsOpen=false; desktop.desktopShortcutsOpen=false;desktop.widgetPacksOpen=false;desktop.welcomeOpen=false;desktop.layoutOpen=false;desktop.dismissSettings(); desktop.dismissControls(); desktop.dismissLauncher(); desktop.dismissDrives();if(desktop.emojiOpen)desktop.closeEmoji();desktop.webAppsOpen=false; }
        function openPage(page: string): void { if (Catalog.pages.some(p=>p.title===page)) desktop.openSettings(page); }
        function settingsMetrics(): string {return JSON.stringify(settingsLoader.item?.contentMetrics??{});}
        function openInstaller():void {desktop.clearPopups();Quickshell.execDetached(["forynarch-setup"]);}
        function openControls(): void { desktop.openControls(); }
        function openLauncher(): void { desktop.openLauncher(); }
        function openEmoji(): void { desktop.openEmoji(); }
        function openWebApps():void {desktop.openWebApps();}
        function refreshWindowMode():void {if(!windowModeStatus.running)windowModeStatus.running=true;}
        function openDrives(): void { desktop.openDrives(); }
        function media(action:string):void {if(!desktop.player)return;if(action==="next"&&desktop.player.canGoNext)desktop.player.next();if(action==="previous"&&desktop.player.canGoPrevious)desktop.player.previous();if(action==="toggle"&&desktop.player.canTogglePlaying)desktop.player.togglePlaying();}
        function setWidget(key: string, enabled: bool): void { desktop.setWidget(key,enabled); }
        function editWidgets(): void {desktop.editWidgets();}
        function finishWidgets(commit:bool):void {desktop.finishWidgetEdit(commit);}
        function moveWidget(key: string, delta: int): void { if(delta===1 || delta===-1) desktop.moveWidget(key,delta); }
        function setWidgetsRight(enabled: bool): void { desktop.setWidgetsRight(enabled); }
        function setWidgetScale(percent: int): void { desktop.setWidgetScale(percent/100); }
        function setMotion(enabled: bool): void { desktop.setMotion(enabled); }
        function setMotionBlur(enabled: bool): void { desktop.setMotionBlur(enabled); }
        function setGlass(enabled: bool): void { desktop.setGlass(enabled); }
        function setApplicationGlass(enabled: bool): void { desktop.setApplicationGlass(enabled); }
        function setApplicationOpacity(value: int): void { desktop.setApplicationOpacity(value); }
        function setWidgets(enabled: bool): void { desktop.setWidgets(enabled); }
        function setPanel(key:string,value:bool):void {desktop.setPanel(key,value);}
        function setPanelSpacing(value:int):void {desktop.setPanel("panelSpacing",value);}
        function setIslands(enabled: bool): void { desktop.setIslands(enabled); }
        function setBottomPanel(enabled: bool): void { desktop.setBottomPanel(enabled); }
        function setClock12(enabled: bool): void { desktop.setClock12(enabled); }
        function setAccent(value: string): void { desktop.setAccent(value); }
        function setFrost(value: int): void { desktop.setFrost(value); }
        function status(): string { return JSON.stringify({glass:desktop.glass,applicationGlass:desktop.applicationGlass,applicationOpacity:desktop.applicationOpacity,widgets:desktop.widgets,widgetsLoaded:widgetLoader.active,
            settingsOpen:desktop.settingsOpen,settingsLoaded:settingsLoader.active,
            controlOpen:desktop.controlOpen,controlsLoaded:controlsLoader.active,
            panelShowLauncher:desktop.panelShowLauncher,panelShowTray:desktop.panelShowTray,panelShowNotifications:desktop.panelShowNotifications,panelShowAudio:desktop.panelShowAudio,panelShowControls:desktop.panelShowControls,panelShowBattery:desktop.panelShowBattery,panelShowSettings:desktop.panelShowSettings,batteryOpen:desktop.batteryOpen,
page:desktop.settingsPage,panelCompact:desktop.panelCompact,panelSpacing:desktop.panelSpacing,previewLive:desktop.previewLive,autoSnap:desktop.autoSnap,islands:desktop.islands,bottomPanel:desktop.bottomPanel,
            clock12:desktop.clock12,frost:desktop.frost,accent:desktop.accent,
            launcherOpen:desktop.launcherOpen,launcherLoaded:launcherLoader.active,drivesOpen:desktop.drivesOpen,drivesLoaded:driveLoader.active,
            motion:desktop.motion,motionBlur:desktop.motionBlur,
            widgetFlags:[desktop.widgetClock,desktop.widgetCalendar,desktop.widgetGreeting,desktop.widgetMedia],
            widgetOrder:desktop.widgetOrder,widgetScale:desktop.widgetScale,widgetsRight:desktop.widgetsRight,widgetEditing:desktop.widgetEditing,widgetPositions:desktop.widgetPositions,widgetExtras:desktop.widgetExtras,emojiOpen:desktop.emojiOpen,emojiLoaded:emojiLoader.active,desktopShortcutsEnabled:desktop.desktopShortcutsEnabled,desktopShortcutIds:desktop.desktopShortcutIds,widgetPacksOpen:desktop.widgetPacksOpen,customWidgetCount:desktop.customWidgets.length,webAppsOpen:desktop.webAppsOpen,layoutOpen:desktop.layoutOpen,layoutLoaded:layoutLoader.active,layoutWindow:desktop.layoutWindow,windowMode:desktop.windowMode,cavaRunning:cavaProcess.running}); }
    }
    LazyLoader {active:desktop.desktopShortcutsEnabled;component:DesktopShortcuts {controller:desktop}}
    LazyLoader {active:desktop.desktopShortcutsOpen;component:DesktopShortcutManager {controller:desktop}}
    LazyLoader { active:desktop.widgetPacksOpen; component:WidgetPackManager {controller:desktop} }
    LazyLoader { active: desktop.welcomeOpen; component: LiveWelcome { controller: desktop } }
    LazyLoader { id: launcherLoader; active: desktop.launcherOpen || desktop.launcherClosing; component: Launcher { controller: desktop } }
    LazyLoader { id:emojiLoader;active:desktop.emojiOpen || desktop.emojiClosing; component:EmojiPicker {controller:desktop} }
    LazyLoader {active:desktop.webAppsOpen;component:WebApps {controller:desktop}}
    LazyLoader { id: driveLoader; active: desktop.drivesOpen || desktop.drivesClosing; component: DrivesPanel { controller: desktop } }
    LazyLoader{active:desktop.panelStyle!=="macshell";component:DesktopPanel{controller:desktop;apple:false}}
    LazyLoader{active:desktop.panelStyle==="macshell";component:DesktopPanel{controller:desktop;apple:true}}
    LazyLoader {active:desktop.captureOpen;component:CapturePanel{controller:desktop}}
    LazyLoader {active:desktop.clipboardOpen;component:ClipboardPanel{controller:desktop}}

    LazyLoader {active:desktop.batteryOpen;component:BatteryPanel{controller:desktop}}
LazyLoader {active:desktop.trayOpen;component:BackgroundApps {controller:desktop}}
    LazyLoader {active:desktop.notificationsOpen;component:NotificationCenter {controller:desktop}}
    LazyLoader {active:desktop.snapPreview.region!=="";component:SnapOverlay {controller:desktop}}
    LazyLoader { id: layoutLoader; active: desktop.layoutOpen; component: WindowLayoutPicker { controller: desktop; windowAddress: desktop.layoutWindow } }
    LazyLoader { id:widgetLoader; active:desktop.widgetEditing || desktop.widgets && desktop.widgetKeys.some(key=>desktop.widgetEnabled(key)); component:DesktopWidgets {controller:desktop} }
    LazyLoader { id: settingsLoader; active: desktop.settingsOpen || desktop.settingsClosing; component: SettingsPanel { controller: desktop } }
    Component{id:classicControls;ControlCenter{controller:desktop}}
    Component{id:macControls;MacControlCenter{controller:desktop}}
    LazyLoader {id:controlsLoader;active:desktop.controlOpen||desktop.controlsClosing;component:desktop.controlCenterStyle==="macshell"?macControls:classicControls}

}
