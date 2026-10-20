import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: welcome
    objectName: "installerWelcome"
    required property bool reduceMotion
    property bool installerReady:false
    readonly property bool effectAnimating: arrival.running
    readonly property int effectStatus: silk.status
    spacing: 16

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 244
        radius: 18
        color: "#122338"
        border.color: "#30465e"

        ShaderEffect {
            id: silk
            anchors.fill: parent
            // One bounded, texture-free pass. No frame timer or idle animation.
            property vector2d extent: Qt.vector2d(width, height)
            property real reveal: 1
            fragmentShader: Qt.resolvedUrl("shaders/welcome.frag.qsb")
            visible: status !== ShaderEffect.Error
            Accessible.ignored: true
            Component.onCompleted: if (!welcome.reduceMotion) arrival.start()
            NumberAnimation {
                id: arrival
                target: silk; property: "reveal"
                from: 0; to: 1; duration: 680
                easing.type: Easing.OutCubic
            }
            Connections {
                target: welcome
                function onReduceMotionChanged() {
                    if (welcome.reduceMotion) { arrival.stop(); silk.reveal = 1; }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    implicitWidth: badge.implicitWidth + 24; implicitHeight: 28
                    radius: 14; color: "#1a334d"; border.color: "#426183"
                    Text { id: badge; anchors.centerIn: parent; text: "Hyprland desktop"; color: "#b4dbff"; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: liveLabel.implicitWidth + 16; implicitHeight: 24
                    radius: 4; color: "#0d1b2c"
                    Text { id: liveLabel; anchors.centerIn: parent; text: "LIVE INSTALLER"; color: "#b1c7df"; font.pixelSize: 10; font.letterSpacing: 1 }
                }
            }
            Item { Layout.fillHeight: true }
            Text { text: "Set up your desktop."; color: "#edf5ff"; font.pixelSize: welcome.width < 600 ? 27 : 32; font.weight: Font.DemiBold }
            SetupText {
                Layout.maximumWidth: Math.min(420, welcome.width - 52)
                text: "An independent Arch Linux system, with the Hyprland desktop and the essentials you choose."
                font.pixelSize: 14; color: "#c5d8ee"
            }
        }
    }

    GridLayout {
    Layout.fillWidth: true
    columns: welcome.width >= 720 ? 2 : 1
    columnSpacing: 16; rowSpacing: 16
    Repeater {
        model: [
            { icon: "account", title: "Account and storage", detail: "Choose your disk, partition layout, user account and hardware options." },
            { icon: "software", title: "Optional software", detail: "Add the applications you need. Developer tools start unchecked." }
        ]
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: Math.max(86, featureCopy.implicitHeight + 32)
            radius: 12; color: "#142338"; border.color: "#2a4059"
            RowLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 16
                Rectangle {
                    implicitWidth: 42; implicitHeight: 42; radius: 10
                    color: "#1a3049"; border.color: "#365575"
                    Canvas {
                        anchors.centerIn: parent; width: 22; height: 22
                        Accessible.ignored: true
                        onPaint: {
                            const c = getContext("2d"); c.reset(); c.strokeStyle = "#9acbff"; c.lineWidth = 1.5;
                            if (modelData.icon === "account") {
                                c.strokeRect(4, 3, 14, 16); c.beginPath();
                                c.arc(11, 8, 2, 0, Math.PI * 2); c.moveTo(7, 16); c.bezierCurveTo(7, 11, 15, 11, 15, 16); c.stroke();
                            } else {
                                c.strokeRect(3, 8, 16, 11); c.strokeRect(6, 3, 10, 5);
                                c.beginPath(); c.moveTo(3, 12); c.lineTo(19, 12); c.stroke();
                            }
                        }
                    }
                }
                ColumnLayout {
                    id: featureCopy; Layout.fillWidth: true; spacing: 6
                    Text { text: modelData.title; color: "#e1eeff"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    SetupText { text: modelData.detail; font.pixelSize: 13 }
                }
            }
        }
    }
    }

    SetupText {
        text: "Use Forynarch on its own, or preserve another operating system."
        font.pixelSize: 12
        Layout.leftMargin: 4
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: reviewCopy.implicitHeight + 32
        radius: 12; color: "#302a24"; border.color: "#62503a"
        ColumnLayout {
            id: reviewCopy
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
            spacing: 6
            Text { text: welcome.installerReady?"Review before installation":"Installation media unavailable"; color: "#f2c5aa"; font.pixelSize: 13; font.weight: Font.DemiBold }
            SetupText { text: welcome.installerReady?"Choose your account, storage and optional software. Disk changes require a final disk-specific confirmation.":"You can review the setup steps. A matching system payload is required before installation can start."; color: "#f2d7c5"; font.pixelSize: 12 }
        }
    }
}
