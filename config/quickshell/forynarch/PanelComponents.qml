import QtQuick
import QtQuick.Layouts

ColumnLayout {
required property var controller
spacing:10
Repeater {
                model:[{key:"panelShowLauncher",title:"Applications launcher"},{key:"panelShowTray",title:"Background apps"},{key:"panelShowNotifications",title:"Notifications"},{key:"panelShowAudio",title:"Audio button"},{key:"panelShowControls",title:"Control Center button"},{key:"panelShowBattery",title:"Battery indicator"},{key:"panelShowSettings",title:"Settings button"},{key:"panelShowApps",title:"Running applications"},{key:"panelShowWorkspaces",title:"Workspace slots"},{key:"panelShowClock",title:"Clock and date"},{key:"panelShowMode",title:"Workspace mode label"},{key:"panelShowNetwork",title:"Network button"},{key:"panelShowPower",title:"Power button"},{key:"panelShowDesktop",title:"Show desktop button"},{key:"previewLive",title:"Live window previews"}]
                SettingRow {
                    required property var modelData
                    Layout.fillWidth:true;title:modelData.title;description:modelData.key==="previewLive"?"Refresh supported thumbnails while their popup is open":""
                    Toggle {checked:controller[modelData.key];accent:controller.accent;Accessible.name:modelData.title;onClicked:controller.setPanel(modelData.key,checked)}
                }
            }
            }
