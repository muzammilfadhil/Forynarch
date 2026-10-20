import QtQuick
import QtQuick.Controls
TextField {
    id:field
    implicitHeight:44
    color:"#e2eeff"
    placeholderTextColor:"#849bb5"
    selectByMouse:true
    selectionColor:"#476c94"
    selectedTextColor:"#ffffff"
    font.pixelSize:14
    background:Rectangle {radius:5;color:"#0d1929";border.color:field.activeFocus?"#9acbff":"#6483a3";border.width:1}
}
