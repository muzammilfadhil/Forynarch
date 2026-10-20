import QtQuick

Rectangle {
    id: card
    property bool glass: true
    property real frost: 4
    radius: 20
    color: glass ? "#a6111823" : "#111823"
    border.width: 1
    border.color: "#304057"
    // Hyprland blurs the actual surface behind this translucent layer.
}
