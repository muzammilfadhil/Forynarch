// Config created by Keyitdev https://github.com/Keyitdev/sddm-astronaut-theme
// Copyright (C) 2022-2025 Keyitdev
// Based on https://github.com/MarianArlt/sddm-sugar-dark
// Distributed under the GPLv3+ License https://www.gnu.org/licenses/gpl-3.0.html
import QtQuick
import QtQuick.Controls

Column {
    id: clock
    width: Math.min(parent.width - 80, 336)
    spacing: 8
    property date now: new Date()

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Image {
            width: 22; height: 22
            source: "file:///usr/share/forynarch/branding/logo.svg"
            fillMode: Image.PreserveAspectFit
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: String(config.HeaderText || "Forynarch").toUpperCase()
            color: "#a3b4cb"; font.pixelSize: 12; font.letterSpacing: 3
            renderType: Text.QtRendering
        }
    }
    Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: clock.now.toLocaleTimeString(Qt.locale(config.Locale), config.HourFormat || "HH:mm")
        color: "#e4f1ff"; font.pixelSize: root.height < 700 ? 64 : 80
        font.weight: Font.Light; font.letterSpacing: -3
        renderType: Text.QtRendering
    }
    Label {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: clock.now.toLocaleDateString(Qt.locale(config.Locale), config.DateFormat || "dddd d")
        color: "#adc2db"; font.pixelSize: 14
        renderType: Text.QtRendering
    }
    Item {
        width: parent.width; height: 28
        Rectangle {
            anchors.centerIn: parent; width: 42; height: 1
            color: "#76c0ec"
            Rectangle { anchors.centerIn: parent; width: 46; height: 5; radius: 2; color: "#1676c0ec" }
        }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
}
