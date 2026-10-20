import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "SettingsCatalog.js" as Catalog
import "WidgetPacks.js" as Packs

PanelWindow {
    id: window
    required property var controller
    readonly property var pages: Catalog.pages
    readonly property int pageIndex: pages.findIndex(p=>p.title===controller.settingsPage)
    readonly property var contentMetrics: ({contentHeight:scroll.contentHeight,viewportHeight:scroll.height,
        contentY:scroll.contentItem?.contentY??0,loaderHeight:pageLoader.height,itemHeight:pageLoader.item?.implicitHeight??0})
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"; focusable: controller.settingsOpen
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "forynarch-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: controller.settingsOpen?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    Rectangle { anchors.fill: parent; color: "#59070c15"; opacity: motionPane.progress }
    MouseArea { anchors.fill: parent; onClicked: controller.dismissSettings() }
    MotionSurface {
    id: motionPane
    controller: window.controller; shown: window.controller.settingsOpen
    anchors.centerIn: parent
    width: Math.min(parent.width-64,1000); height: Math.min(parent.height-96,660)
    GlassCard { anchors.fill: parent; radius: 24; glass: controller.glass; frost: controller.frost }
    MouseArea { anchors.fill: parent }
    FocusScope {
        anchors.fill: parent; focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: controller.dismissSettings()
        Rectangle {
            x: 12; y: 12; width: 196; height: parent.height-24; radius: 18; color: "#e0121b27"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 6
                RowLayout {
                    Layout.fillWidth: true; Layout.topMargin: 8; Layout.bottomMargin: 18; spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 16; color: "#2b4463"
                        Icon { anchors.centerIn: parent; name: "spark"; ink: controller.accent; size: 22 }
                    }
                    Column {
                        spacing: 4
                        Text { text: controller.userName; width: 96; elide: Text.ElideRight; color: "#dfe9f8"; font.family: "Adwaita Sans"; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "Forynarch"; color: "#8296b2"; font.family: "Adwaita Sans"; font.pixelSize: 11 }
                    }
                }
                TextField {
                    id:categorySearch;Layout.fillWidth:true;implicitHeight:36;placeholderText:"Search settings";placeholderTextColor:"#91a8c3";color:"#dceaff"
                    background:Rectangle {radius:10;color:"#203249";border.width:1;border.color:"#38506c"}
                }
                ScrollView {
                    id:categoryScroll;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth;contentHeight:categoryColumn.implicitHeight
                    ScrollBar.horizontal.policy:ScrollBar.AlwaysOff
                ColumnLayout {
                    id:categoryColumn;width:categoryScroll.availableWidth;spacing:4
                Repeater {
                    model: window.pages.filter(p=>(p.title+" "+p.detail+" "+p.keywords).toLowerCase().includes(categorySearch.text.toLowerCase()))
                    ActionButton { animateHover:controller.motion;
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 40; leftAligned: true; rounding: 12
                        icon: modelData.icon; label: modelData.title; quiet: true
                        hint: modelData.detail
                        selected: controller.settingsPage===modelData.title; accent: controller.accent
                        onClicked: controller.settingsPage=modelData.title
                    }
                }
                }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#263549" }
                Text { text: "Settings"; color: "#7187a3"; font.family: "Adwaita Sans"; font.pixelSize: 11; Layout.topMargin: 10 }
                Text { text: "Esc to close"; color: "#7187a3"; font.family: "Adwaita Sans"; font.pixelSize: 11; Layout.bottomMargin: 4 }
            }
        }
        ColumnLayout {
            x: 234; y: 26; width: parent.width-260; height: parent.height-50; spacing: 20
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 44
                Rectangle {
                    x: 0; y: 4; width: 32; height: 32; radius: 12; color: "#293f5a"
                    Icon { anchors.centerIn: parent; name: window.pages[Math.max(0,window.pageIndex)].icon; size: 18; ink: controller.accent }
                }
                ColumnLayout {
                    x: 44; width: parent.width-88; spacing: 3
                    Text { text: controller.settingsPage; color: "#e5efff"; font.family: "Adwaita Sans"; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { text: window.pages[Math.max(0,window.pageIndex)].detail; color: "#8b9cb5"; font.family: "Adwaita Sans"; font.pixelSize: 12 }
                }
                ActionButton { animateHover:controller.motion; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: "close"; hint: "Close settings · Esc"; quiet: true; implicitWidth: 34; implicitHeight: 34; onClicked: controller.dismissSettings() }
            }
            ScrollView {
                id: scroll; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                contentWidth: availableWidth
                contentHeight: pageLoader.height
                wheelEnabled: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                Loader {
                    id: pageLoader
                    width: scroll.availableWidth
                    height: item ? item.implicitHeight : 0
                    onLoaded: scroll.contentItem.contentY = 0
                    sourceComponent: controller.settingsPage==="Appearance" ? appearancePage :
                        controller.settingsPage==="Panel" ? panelPage :
                        controller.settingsPage==="Desktop" ? desktopPage :
                    controller.settingsPage==="Files" ? filesPage :
        controller.settingsPage==="Default Apps" ? defaultAppsPage :
                    controller.settingsPage==="Screenshots & Clipboard" ? capturePage :
        controller.settingsPage==="Date & Time" ? dateTimePage :
        controller.settingsPage==="Notifications" ? notificationsPage :
                controller.settingsPage==="Virtual Machines" ? virtualMachinesPage :
                        controller.settingsPage==="Shortcuts" ? shortcutsPage : systemPage
                }
            }
        }
    }
    }
    Component {
        id: systemPage
        SystemPage {controller:window.controller;pageTitle:window.controller.settingsPage}
    }
    Component {id:notificationsPage;NotificationsPage {controller:window.controller}}
    Component {id:virtualMachinesPage;VirtualMachinesPage {controller:window.controller}}
    Component {id:dateTimePage;DateTimePage {controller:window.controller}}
Component {id:defaultAppsPage;DefaultAppsPage {controller:window.controller}}
    Component {id:capturePage;CapturePage {controller:window.controller}}
Component {id:filesPage;FilesPage {controller:window.controller}}
    Component {
        id: appearancePage
        ColumnLayout {
            spacing: 10
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 176; radius: 18; color: "#192230"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 18
                    MiniDesktop { Layout.fillWidth: true; Layout.fillHeight: true; accent: controller.accent; islands: controller.islands&&controller.panelStyle!=="macshell"; bottomPanel: controller.bottomPanel }
                    ColumnLayout {
                        Layout.preferredWidth: 158; spacing: 8
                        Text { text: "Blue Hour"; color: "#e5efff"; font.family: "Adwaita Sans"; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { text: "Soft folds. Quiet blues."; color: "#8b9cb5"; font.family: "Adwaita Sans"; font.pixelSize: 12 }
                        Item { Layout.preferredHeight: 10 }
                        RowLayout { Icon { name: "check"; size: 15; ink: controller.accent } Text { text: "Current wallpaper"; color: controller.accent; font.family: "Adwaita Sans"; font.pixelSize: 11 } }
                    }
                }
            }
            SettingRow {
                Layout.fillWidth: true; implicitHeight: 88; title: "Accent color"; description: "A shared color across your desktop"
                Repeater {
                    model: [{color:"#9acbff",name:"Sky"},{color:"#a5b8ed",name:"Slate"},{color:"#9bcbd1",name:"Ice"}]
                    Column {
                        required property var modelData
                        spacing: 5
                        AbstractButton {
                            width: 38; height: 34; checkable: false
                            Accessible.name: modelData.name+" accent"
                            background: Rectangle {
                                radius: 12; color: modelData.color
                                border.width: parent.activeFocus ? 2 : 0; border.color: "#ffffff"
                                Icon { anchors.centerIn: parent; name: "check"; size: 16; ink: "#102338"; visible: controller.accent===modelData.color }
                            }
                            onClicked: controller.setAccent(modelData.color)
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: "#8b9cb5"; font.family: "Adwaita Sans"; font.pixelSize: 10 }
                    }
                }
            }
            SettingRow {
                Layout.fillWidth: true; title: "Glass surfaces"; description: "Soft blur and subtle shader texture"
                Toggle { checked: controller.glass; accent: controller.accent; Accessible.name: "Glass surfaces"; onClicked: controller.setGlass(checked) }
            }
            SettingRow {
                Layout.fillWidth:true; title:"Application backgrounds"; description:"Supported apps · Restart apps to apply"
                Toggle {checked:controller.applicationGlass; enabled:controller.glass; accent:controller.accent; Accessible.name:"Application glass backgrounds"; onClicked:controller.setApplicationGlass(checked)}
            }
            SettingRow {
                Layout.fillWidth:true; title:"Background opacity"; description:"Text and controls stay solid"
                Repeater {
                    model:[{value:92,title:"Dense"},{value:84,title:"Balanced"},{value:76,title:"Clear"}]
                    ActionButton {required property var modelData; animateHover:controller.motion;label:modelData.title;selected:controller.applicationOpacity===modelData.value;accent:controller.accent;enabled:controller.glass&&controller.applicationGlass;onClicked:controller.setApplicationOpacity(modelData.value)}
                }
            }
            SettingRow {
                Layout.fillWidth: true; title: "Blur strength"; description: controller.glass ? "Choose how much detail shows through" : "Enable glass to change blur"
                Repeater {
                    model: [{value:2,title:"Soft"},{value:4,title:"Balanced"},{value:6,title:"Rich"}]
                    ActionButton { animateHover:controller.motion;
                        required property var modelData
                        label: modelData.title; selected: controller.frost===modelData.value; accent: controller.accent; enabled: controller.glass
                        implicitHeight: 32; onClicked: controller.setFrost(modelData.value)
                    }
                }
            }
            SettingRow {
                Layout.fillWidth:true; title:"Reduced motion"; description:"Keep transitions still"
                Toggle { checked:!controller.motion; accent:controller.accent; Accessible.name:"Reduced motion"; onClicked:controller.setMotion(!checked) }
            }
            SettingRow {
                Layout.fillWidth:true; title:"Motion blur"; description:"A brief directional blur during transitions"
                Toggle { checked:controller.motionBlur; enabled:controller.motion; accent:controller.accent; Accessible.name:"Motion blur"; onClicked:controller.setMotionBlur(checked) }
            }
        }
    }
    Component {
        id: panelPage
        ColumnLayout {
            spacing: 10
ComponentStyles{Layout.fillWidth:true;controller:window.controller}
PanelCustomization{Layout.fillWidth:true;controller:window.controller}
            MiniDesktop { Layout.fillWidth: true; Layout.preferredHeight: 176; accent: controller.accent; islands: controller.islands&&controller.panelStyle!=="macshell"; bottomPanel: controller.bottomPanel }
            SettingRow {
                Layout.fillWidth:true;title:"Alignment";description:"Keep groups spaced across the screen or bring them together"
                Choice {choices:[{label:"Spaced",value:false},{label:"Compact",value:true}];selectedValue:controller.panelCompact;onChosen:value=>controller.setPanel("panelCompact",value)}
            }
            SettingRow {
                Layout.fillWidth:true;title:"Group spacing";description:"Gap between compact panel groups"
                Choice {choices:[8,12,18,24].map(value=>({label:value+" px",value:value}));selectedValue:controller.panelSpacing;onChosen:value=>controller.setPanel("panelSpacing",value)}
            }
            PanelComponents {Layout.fillWidth:true;controller:window.controller}
SettingRow {
                Layout.fillWidth: true; title: "Panel position"; description: "Keep essentials within reach"
                ActionButton { animateHover:controller.motion; label: "Top"; selected: !controller.bottomPanel; accent: controller.accent; onClicked: controller.setBottomPanel(false) }
                ActionButton { animateHover:controller.motion; label: "Bottom"; selected: controller.bottomPanel; accent: controller.accent; onClicked: controller.setBottomPanel(true) }
            }
            SettingRow {
                Layout.fillWidth: true; title: "Panel layout"; description: "One surface or three quiet groups"
                ActionButton { animateHover:controller.motion; label: "Continuous"; selected: !controller.islands; accent: controller.accent; onClicked: controller.setIslands(false) }
                ActionButton { animateHover:controller.motion; label: "Islands"; selected: controller.islands; accent: controller.accent; onClicked: controller.setIslands(true) }
            }
            SettingRow {
                Layout.fillWidth: true; title: "Applications"; description: "Search and open an installed app"
                ActionButton { animateHover:controller.motion; icon: "grid"; label: "Open launcher"; onClicked: { controller.dismissSettings(); controller.openLauncher(); } }
            }
        }
    }
    Component {
        id: desktopPage
        ColumnLayout {
            spacing:10
            SettingRow {
                Layout.fillWidth:true;title:"Workspace mode";description:"Applies to the focused workspace. Manual window overrides stay independent."
            }
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
                Repeater {model:[{id:"hybrid",label:"Hybrid"},{id:"dwindle",label:"Tiling"},{id:"master",label:"Master"},{id:"scrolling",label:"Scrolling"},{id:"floating",label:"Floating"}]
                    ActionButton {required property var modelData;label:modelData.label;selected:controller.windowMode===modelData.id;implicitHeight:44;onClicked:controller.run(["forynarch-window-mode",modelData.id].concat(controller.applyModeToOpen?["--apply-open"]:[]))}
                }
            }
            ConnectivityCheck {text:"Also float or tile the open windows";checked:controller.applyModeToOpen;onToggled:controller.applyModeToOpen=checked}
            ActionButton {label:controller.windowMode==="floating"?"Restore previous workspace layout":"Float all windows in this workspace";implicitHeight:44;onClicked:controller.run(["forynarch-window-control","toggle-all"])}
            Text {text:"Hybrid tiles main apps and floats File Manager and utilities. Defaults affect new windows. Use the option above only to change open windows.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            SettingRow {
                Layout.fillWidth:true;title:"Snap floating windows";description:"Drag to an edge for a shared layout; drag to the top for layout choices"
                Toggle {checked:controller.autoSnap;accent:controller.accent;Accessible.name:"Snap floating windows";onClicked:controller.setPanel("autoSnap",checked)}
            }
            SettingRow {Layout.fillWidth:true;title:"Floating window size";description:"Starting size for new floating windows in this workspace"}
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
                Repeater {model:[{id:"compact",label:"Compact"},{id:"comfortable",label:"Comfortable"},{id:"spacious",label:"Spacious"}]
                    ActionButton {required property var modelData;label:modelData.label;selected:controller.floatingSize===modelData.id;implicitHeight:44;onClicked:controller.run(["forynarch-window-mode","size",modelData.id])}
                }
            }
            Text {text:"Drag a window edge to resize. Super + left drag moves a window; Super + right drag resizes it. Your manual size remains until you change it.";color:"#b5c9e3";font.pixelSize:12;wrapMode:Text.WordWrap;Layout.fillWidth:true}
            ActionButton {label:"Float and resize active window";implicitHeight:44;hint:"Apply this workspace's size preset to the last focused app";onClicked:controller.run(["forynarch-window-mode","fit"])}
                    ActionButton {label:"Arrange windows";implicitHeight:44;hint:"";onClicked:controller.openLayout()}
            WindowGeometry {Layout.fillWidth:true;controller:window.controller}
                TitlebarSettings {Layout.fillWidth:true;controller:window.controller}
            MusicSettings {controller:window.controller;Layout.fillWidth:true}
            SettingRow {
                Layout.fillWidth:true;title:"Arrange widgets";description:"Drag, align to a grid or start from a preset"
                ActionButton {label:"Edit layout";implicitHeight:44;onClicked:controller.editWidgets()}
            }
            Flow {
                Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6
                Repeater {model:Packs.packs
                    ActionButton {required property var modelData;label:modelData.label+" pack";hint:modelData.description;implicitHeight:40;onClicked:controller.applyWidgetPack(modelData.id)}
                }
            }
            SettingRow {
                Layout.fillWidth:true;title:"Community widget packs";description:"Import, export or create your own widgets"
                ActionButton {label:"Manage packs";implicitHeight:44;onClicked:controller.openWidgetPacks()}
            }
            SettingRow {
                Layout.fillWidth:true;title:"Desktop application shortcuts";description:"Optional icons · disabled by default"
                Toggle {checked:controller.desktopShortcutsEnabled;Accessible.name:"Show desktop shortcuts";onClicked:{controller.desktopShortcutsEnabled=checked;controller.save();}}
                ActionButton {label:"Choose apps";implicitHeight:44;onClicked:controller.openDesktopShortcuts()}
            }
            SettingRow {
                Layout.fillWidth:true; title:"Show desktop widgets"; description:"Your selection stays saved when hidden"
                Toggle { checked:controller.widgets; accent:controller.accent; Accessible.name:"Show desktop widgets"; onClicked:controller.setWidgets(checked) }
            }
            Repeater {
                model:controller.widgetCatalog.map(row=>row.id)
                SettingRow {
                    required property string modelData
                    required property int index
                    Layout.fillWidth:true; implicitHeight:58
                    title:controller.widgetCatalog.find(row=>row.id===modelData)?.label||modelData
                    Toggle { checked:controller.widgetEnabled(modelData); accent:controller.accent; Accessible.name:"Show "+modelData+" widget"; onClicked:controller.setWidget(modelData,checked) }
                }
            }
            SettingRow {
                Layout.fillWidth:true; title:"Widget placement"; description:"Choose a side for your widget column"
                ActionButton { animateHover:controller.motion; label:"Left"; selected:!controller.widgetsRight; accent:controller.accent; onClicked:controller.setWidgetsRight(false) }
                ActionButton { animateHover:controller.motion; label:"Right"; selected:controller.widgetsRight; accent:controller.accent; onClicked:controller.setWidgetsRight(true) }
            }
            SettingRow {
                Layout.fillWidth:true; title:"Widget size"; description:"Automatically fits smaller screens"
                Repeater {
                    model:[{size:0.8,title:"Small"},{size:1,title:"Medium"},{size:1.2,title:"Large"}]
                    ActionButton { animateHover:controller.motion; required property var modelData; label:modelData.title; selected:controller.widgetScale===modelData.size; accent:controller.accent; onClicked:controller.setWidgetScale(modelData.size) }
                }
            }
            SettingRow {
                Layout.fillWidth:true; title:"12-hour clock"; description:controller.clock12 ? "Time includes AM or PM" : "Time uses the 24-hour format"
                Toggle { checked:controller.clock12; accent:controller.accent; Accessible.name:"12-hour clock"; onClicked:controller.setClock12(checked) }
            }
        }
    }
    Component {
        id: shortcutsPage
        ShortcutEditor { controller:window.controller }
    }
}
