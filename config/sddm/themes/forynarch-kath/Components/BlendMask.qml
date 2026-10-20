import QtQuick
Rectangle {
    property bool reversed: false
    visible: false
    layer.enabled: true
    layer.textureSize: Qt.size(256, 1)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {position: 0; color: reversed ? "transparent" : "white"}
        GradientStop {position: reversed ? 0.28 : 0.72; color: "white"}
        GradientStop {position: 1; color: reversed ? "white" : "transparent"}
    }
}
