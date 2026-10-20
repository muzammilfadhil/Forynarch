import QtQuick
Item {
    id:meter
    required property var controller
    property bool active:false
    readonly property var values:meter.active?controller.cavaValues:[]
    implicitWidth:190;implicitHeight:22
    Row {
        anchors.bottom:parent.bottom;spacing:4;height:meter.height
        Repeater {
            model:16
            Rectangle {
                required property int index
                width:8;height:Math.max(2,(meter.values[index]||0)*meter.height/100);radius:2
                color:meter.controller.accent;opacity:0.45+(index%4)*0.12
                anchors.bottom:parent.bottom
            }
        }
    }
}
