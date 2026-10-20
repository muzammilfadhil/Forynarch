import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "WidgetPalette.js" as Palette

Scope {
    id: widgets
    required property var controller
    property bool editing:controller.widgetEditing
    property var cards: [clockCard,calendarCard,greetingCard,mediaCard,digitalCard,focusCard,systemCard,batteryCard,launchpadCard,shortcutsCard]
    Component {id:digitalCard;ExtraWidget {controller:widgets.controller;kind:"digital"}}
    Component {id:focusCard;ExtraWidget {controller:widgets.controller;kind:"focus"}}
    Component {id:systemCard;ExtraWidget {controller:widgets.controller;kind:"system"}}
    Component {id:batteryCard;ExtraWidget {controller:widgets.controller;kind:"battery"}}
    Component {id:launchpadCard;ExtraWidget {controller:widgets.controller;kind:"launchpad"}}
    Component {id:shortcutsCard;ExtraWidget {controller:widgets.controller;kind:"shortcuts"}}
    WidgetSurface {controller:widgets.controller;cards:widgets.cards}
    Component { id: clockCard
        Item {
            width: 224; height: 224
            ClockFace { anchors.fill: parent; time: controller.now; accent: controller.accent }
            Rectangle {
                x: 4; y: 12; width: 48; height: 48; radius: 18; color: controller.accent
                Text { anchors.centerIn: parent; text: controller.now.getDate(); font.family: "Adwaita Sans"; font.pixelSize: 22; font.weight: Font.Bold; color: "#102338" }
            }
            Rectangle {
x: 169; y: 170; width: 50; height: 44; radius: 20; color: Palette.chip; border.width: 1; border.color: Palette.edge
Text { anchors.centerIn: parent; text: Qt.formatDateTime(controller.now,"MM"); font.family: "Adwaita Sans"; font.pixelSize: 21; color: Palette.primary; font.weight: Font.DemiBold }
            }
        }
    }
    Component { id: calendarCard
        GlassCard {
            width: 224; height: 130; glass: controller.glass; frost: controller.frost; radius: 24
color: glass ? Palette.surface : Palette.opaqueSurface; border.color: Palette.edge
            Column {
                anchors.fill: parent; anchors.margins: 16; spacing: 12
                Rectangle {
width: month.implicitWidth+20; height: 25; radius: 12; color: Palette.chip
Text { id: month; anchors.centerIn: parent; text: Qt.formatDateTime(controller.now,"MMMM yyyy"); font.family: "Adwaita Sans"; font.pixelSize: 12; color: Palette.primary; font.weight: Font.DemiBold }
                }
                Grid {
                    columns: 7; columnSpacing: 2; rowSpacing: 7
                    Repeater {
                        model: ["M","T","W","T","F","S","S"]
Text { required property string modelData; width: 25; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Palette.muted; font.family: "Adwaita Sans"; font.pixelSize: 11 }
                    }
                    Repeater {
                        model: 7
                        Rectangle {
                            required property int index
                            readonly property date day: new Date(controller.now.getFullYear(),controller.now.getMonth(),controller.now.getDate()-(controller.now.getDay()+6)%7+index)
                            width: 25; height: 25; radius: 13
                            color: day.getDate() === controller.now.getDate() ? controller.accent : "transparent"
                            Text { anchors.centerIn: parent; text: parent.day.getDate(); color: parent.day.getDate() === controller.now.getDate() ? "#102338" : "#c9d9ee"; font.family: "Adwaita Sans"; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
    Component { id: greetingCard
        GlassCard {
            width: 224; height: 94; radius: 24; glass: controller.glass; frost: controller.frost
color: glass ? Palette.surface : Palette.opaqueSurface; border.color: Palette.edge
            RowLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 12
                Rectangle {
Layout.preferredWidth: 52; Layout.preferredHeight: 58; radius: 18; color: Palette.chip
                    Icon { anchors.centerIn: parent; name: "spark"; size: 26; ink: controller.accent }
                }
                Column {
                    spacing: 4
                    Text { text: "Hi, " + controller.userName; color: "#e5efff"; font.family: "Adwaita Sans"; font.pixelSize: 15; font.weight: Font.DemiBold; width: 128; elide: Text.ElideRight }
                    Text { text: controller.now.getHours()<12 ? "Good morning" : (controller.now.getHours()<18 ? "Good afternoon" : "Good evening"); color: "#a5b9d2"; font.family: "Adwaita Sans"; font.pixelSize: 12 }
Text { text: Qt.formatDateTime(controller.now,"dddd, dd MMM"); color: Palette.muted; font.family: "Adwaita Sans"; font.pixelSize: 11 }
                }
            }
        }
    }
    Component {id:mediaCard;MediaWidget {controller:widgets.controller}}
}
