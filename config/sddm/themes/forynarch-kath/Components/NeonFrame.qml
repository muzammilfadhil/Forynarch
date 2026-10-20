import QtQuick
import QtQuick.Effects

Item {
    id: frame
    property bool highlighted: false
    property bool reduceMotion: false
    property color fill: "#d9111f32"
    property color accent: "#76c0ec"
    property real radius: 8
    property real glow: highlighted ? 1 : 0
    Behavior on glow { NumberAnimation { duration: frame.reduceMotion ? 0 : 160; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent; anchors.margins: -6
        radius: frame.radius + 6; color: "transparent"
        border.width: 4; border.color: frame.accent
        opacity: frame.glow * 0.045
    }
    Rectangle {
        anchors.fill: parent; anchors.margins: -2
        radius: frame.radius + 2; color: "transparent"
        border.width: 2; border.color: frame.accent
        opacity: frame.glow * 0.15
    }
    Rectangle {
        anchors.fill: parent; radius: frame.radius; color: frame.fill
        border.width: 1; border.color: frame.highlighted ? frame.accent : "#34495e"
        layer.enabled: frame.glow > 0
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: frame.accent
            shadowOpacity: frame.glow * 0.45; shadowBlur: 0.45
            shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            blurMax: 12; autoPaddingEnabled: true
        }
        Behavior on border.color { ColorAnimation { duration: frame.reduceMotion ? 0 : 160 } }
        Behavior on color { ColorAnimation { duration: frame.reduceMotion ? 0 : 160 } }
    }
}
