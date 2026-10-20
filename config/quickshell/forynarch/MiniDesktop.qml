import QtQuick

Rectangle {
    id: preview
    property color accent: "#9acbff"
    property bool islands: true
    property bool bottomPanel: false
    radius: 16; color: "#0c1422"; clip: true
    Image { anchors.fill: parent; source: "file:///usr/share/backgrounds/forynarch/navy.svg"; sourceSize: Qt.size(640,360); fillMode: Image.PreserveAspectCrop }
    Row {
        x: 10; y: preview.bottomPanel ? preview.height-23 : 10; width: parent.width-20; spacing: 8
        Rectangle { width: preview.islands ? parent.width*.22 : parent.width; height: 13; radius: 6; color: "#d2111823"; border.width: 1; border.color: "#33465e" }
        Rectangle { visible: preview.islands; width: parent.width*.48-16; height: 13; radius: 6; color: "#d2111823"; Rectangle { anchors.centerIn: parent; width: 28; height: 4; radius: 2; color: preview.accent } }
        Rectangle { visible: preview.islands; width: parent.width*.3; height: 13; radius: 6; color: "#d2111823" }
    }
    Rectangle { x: 18; y: 43; width: 37; height: 37; radius: 17; color: "#2b4463"; Icon { anchors.centerIn: parent; name: "clock"; size: 22; ink: preview.accent } }
    Rectangle { x: 17; y: 86; width: 48; height: 26; radius: 8; color: "#293c55"; Rectangle { x: 7; y: 7; width: 26; height: 4; radius: 2; color: preview.accent } }
}
