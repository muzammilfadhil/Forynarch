import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id: page
    required property var controller
    property bool centerOnly: false
    spacing:12
    NotificationModel {id: notices;controller:page.controller}
    Text {Layout.fillWidth:true;visible:!notices.loaded;text:"Loading notifications…";color:"#b5c9e3"}
    Text {Layout.fillWidth:true;visible:notices.error!=="";text:notices.error;color:"#f2b49b";wrapMode:Text.WordWrap}
    Text {Layout.fillWidth:true;visible:!notices.info.available;text:"The notification service is unavailable. Sign in again to restart it.";color:"#f2b49b";wrapMode:Text.WordWrap}
    SettingRow {
        Layout.fillWidth:true;title:"Notification profile"
        description:notices.info.dnd?"Do Not Disturb is active. Banners stay hidden.":"Notifications remain in recent history for this session."
    }
    Choice {
        Layout.fillWidth:true;choices:[{label:"All notifications",value:"normal"},{label:"Do Not Disturb",value:"dnd"},{label:"Custom focus",value:"custom"}]
        selectedValue:notices.info.dnd?"dnd":notices.info.settings.profile
        enabled:!notices.busy;Accessible.name:"Notification profile";onChosen:value=>notices.setting("profile",value)
    }
    ColumnLayout {
        visible:!page.centerOnly;Layout.fillWidth:true;spacing:12
        SettingRow {Layout.fillWidth:true;title:"Notification banners";description:"Apps can still play their own sounds"
            Toggle {checked:notices.info.settings.enabled;enabled:!notices.busy;Accessible.name:"Notification banners";onClicked:notices.setting("enabled",checked)}
        }
        SettingRow {Layout.fillWidth:true;title:"Banner duration";description:"Critical alerts remain until dismissed"}
        Choice {Layout.fillWidth:true;choices:[3,6,10,15,30].map(n=>({label:n+" seconds",value:n}));selectedValue:notices.info.settings.timeout;enabled:!notices.busy;Accessible.name:"Banner duration";onChosen:value=>notices.setting("timeout",value)}
        ColumnLayout {
            visible:notices.info.settings.profile==="custom";Layout.fillWidth:true;spacing:8
            SettingRow {Layout.fillWidth:true;title:"Allow critical alerts";description:"Custom focus only; Do Not Disturb stays silent"
                Toggle {checked:notices.info.settings.critical;enabled:!notices.busy;Accessible.name:"Allow critical alerts in custom focus";onClicked:notices.setting("critical",checked)}
            }
            Text {Layout.fillWidth:true;text:"Allowed applications";color:"#deebfc";font.pixelSize:14;font.weight:Font.DemiBold}
            Text {Layout.fillWidth:true;text:"Use the application name shown in a notification. Everything else stays in the center without a banner.";color:"#b5c9e3";wrapMode:Text.WordWrap;font.pixelSize:12}
            Repeater {model:notices.info.settings.allow
                RowLayout {required property string modelData;Layout.fillWidth:true
                    Text {text:modelData;Layout.fillWidth:true;color:"#deebfc";elide:Text.ElideRight}
                    ActionButton {label:"Remove";enabled:!notices.busy;onClicked:notices.setting("allow",notices.info.settings.allow.filter(a=>a!==modelData))}
                }
            }
            TextField {id:appName;Layout.fillWidth:true;placeholderText:"Application name, for example Discord";Accessible.name:"Allowed application name";maximumLength:100;color:"#deebfc";placeholderTextColor:"#a6bbd5";background:Rectangle {color:"#203249";radius:8;border.color:appName.activeFocus?controller.accent:"#6f89a8"}}
            ActionButton {label:"Allow application";enabled:!notices.busy&&appName.text.trim()!==""&&!notices.info.settings.allow.includes(appName.text.trim());onClicked:{notices.setting("allow",notices.info.settings.allow.concat([appName.text.trim()]));appName.clear();}}
        }
    }
    RowLayout {Layout.fillWidth:true
        Text {text:"Notifications";color:"#deebfc";font.pixelSize:16;font.weight:Font.DemiBold;Layout.fillWidth:true}
        ActionButton {label:"Dismiss all";enabled:!notices.busy&&notices.info.current.length>0;onClicked:notices.execute("clear",{})}
    }
    Text {Layout.fillWidth:true;visible:notices.loaded&&!notices.info.current.length&&!notices.info.history.length;text:"You're all caught up. New notifications will appear here.";wrapMode:Text.WordWrap;color:"#b5c9e3"}
    Repeater {
        model:notices.info.current.concat(notices.info.history)
        delegate:Rectangle {
            id: notice
            required property var modelData
            Layout.fillWidth:true;implicitHeight:content.implicitHeight+24;radius:12;color:"#172638";border.width:1;border.color:modelData.critical?"#d6ac8e":"#354b65"
            ColumnLayout {id:content;anchors {left:parent.left;right:parent.right;top:parent.top;margins:12} spacing:6
                RowLayout {Layout.fillWidth:true
                    Text {text:notice.modelData.app+(notice.modelData.history?" · Earlier":"");textFormat:Text.PlainText;color:"#a6bbd5";font.pixelSize:11;Layout.fillWidth:true;elide:Text.ElideRight}
                    ActionButton {visible:!notice.modelData.history;icon:"close";implicitWidth:28;implicitHeight:28;Accessible.name:"Dismiss notification";enabled:!notices.busy;onClicked:notices.execute("dismiss",{id:notice.modelData.id})}
                }
                Text {text:notice.modelData.title;textFormat:Text.PlainText;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:"#e5efff";font.pixelSize:13;font.weight:Font.DemiBold}
                Text {text:notice.modelData.body;textFormat:Text.PlainText;visible:text!=="";Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;color:"#c1d1e5";font.pixelSize:12}
                Flow {Layout.fillWidth:true;Layout.preferredHeight:childrenRect.height;spacing:6;visible:!notice.modelData.history
                    Repeater {model:notice.modelData.actions
                        ActionButton {required property var modelData;label:modelData.label;enabled:!notices.busy;onClicked:notices.execute("invoke",{id:notice.modelData.id,action:modelData.id})}
                    }
                    ActionButton {label:"Allow in custom focus";visible:notices.info.settings.profile==="custom"&&!notices.info.settings.allow.includes(notice.modelData.app);enabled:!notices.busy;onClicked:notices.setting("allow",notices.info.settings.allow.concat([notice.modelData.app]))}
                }
            }
        }
    }
    Text {Layout.fillWidth:true;text:"Up to 50 recent notifications are kept in memory for this login session. Earlier notifications cannot reopen actions after the sending app closes them.";color:"#a6bbd5";wrapMode:Text.WordWrap;font.pixelSize:11}
}
