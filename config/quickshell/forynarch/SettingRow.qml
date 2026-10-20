import QtQuick

Rectangle {
    id: row
    property string title: ""
    property string description: ""
    default property alias actions: controls.data
    implicitHeight:Math.max(76,caption.implicitHeight+36); radius:14; color:"#192230"
    data: [
        Item {
            anchors.fill:parent; anchors.margins:18
            Column {
                id:caption
                anchors.left:parent.left; anchors.verticalCenter:parent.verticalCenter
                width:Math.max(0,controls.x-12); spacing:5
                Text { text:row.title; textFormat:Text.PlainText; width:parent.width; color:"#dfe9f8"; font.family:"Adwaita Sans"; font.pixelSize:14; wrapMode:Text.WordWrap }
                Text { text:row.description; textFormat:Text.PlainText; visible:text!==""; width:parent.width; color:"#8b9cb5"; font.family:"Adwaita Sans"; font.pixelSize:12; wrapMode:Text.WordWrap }
            }
            Row { id:controls; anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter; spacing:6 }
        }
    ]
}
