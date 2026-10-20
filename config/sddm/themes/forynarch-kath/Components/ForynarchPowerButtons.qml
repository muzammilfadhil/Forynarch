import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id: power
    property ComboBox exposedSession
    property int pending: -1
    readonly property var actions: [
        {icon:"Shutdown",label:"Shut down",available:sddm.canPowerOff},
        {icon:"Suspend",label:"Sleep",available:sddm.canSuspend},
        {icon:"Hibernate",label:"Hibernate",available:sddm.canHibernate},
        {icon:"Reboot",label:"Restart",available:sddm.canReboot}
    ]
    spacing: 6
    function perform() {
        if (pending < 0 || !actions[pending].available) return;
        const index = pending; confirmation.close();
        if (index === 0) sddm.powerOff();
        else if (index === 1) sddm.suspend();
        else if (index === 2) sddm.hibernate();
        else sddm.reboot();
    }
    RowLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: 6
    Repeater {
        model: power.actions
        Button {
                id: powerActionButton
            required property var modelData
            required property int index
                implicitWidth: 72; implicitHeight: 60
            visible: config.HideSystemButtons !== "true"
            enabled: modelData.available
            text: modelData.label
            display: AbstractButton.TextUnderIcon
            font.pointSize: 9
            icon.source: Qt.resolvedUrl("../Assets/" + modelData.icon + ".svg")
                icon.width: 20; icon.height: 20
            icon.color: enabled ? "#b4dbff" : "#849bb5"
            palette.buttonText: enabled ? "#dceaff" : "#849bb5"
                hoverEnabled: true
                background: Rectangle {
                    radius: 8; color: parent.hovered ? "#b31c3249" : "transparent"
                    border.width: 1; border.color: parent.activeFocus ? "#76c0ec" : "transparent"
                    Behavior on color { ColorAnimation { duration: config.ReduceMotion === "true" ? 0 : 140 } }
                    Behavior on border.color { ColorAnimation { duration: config.ReduceMotion === "true" ? 0 : 140 } }
                }
                transform: Translate {
                    y: powerActionButton.down ? 1 : powerActionButton.hovered ? -2 : 0
                    Behavior on y { NumberAnimation {duration: config.ReduceMotion === "true" ? 0 : 140; easing.type: Easing.OutCubic} }
                }
            Accessible.name: text + (enabled ? "" : ", unavailable on this system")
                ToolTip.visible: hovered && !enabled
            ToolTip.text: enabled ? text : text + " is unavailable on this system"
            onClicked: {power.pending = index; confirmation.open();}
            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
        }
    }
    }
    Text {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        visible: config.PreviewMode !== "true" && power.actions.some(action => !action.available)
        text: power.actions.filter(action => !action.available).map(action => action.label).join(", ") + " unavailable on this system"
        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        color: "#b5cbe3"; font.pixelSize: 11
    }
    Dialog {
        id: confirmation
        objectName: "loginPowerConfirmation"
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(420, (parent?.width || 480)-32)
        padding: 24; modal: true; closePolicy: Popup.CloseOnEscape
        background: Rectangle {radius: 14; color: "#14263b"; border.color: "#6483a3"}
        onOpened: keepLogin.forceActiveFocus()
        onClosed: power.pending = -1
        contentItem: ColumnLayout {
            spacing: 16
            Text {Layout.fillWidth: true; text: power.pending < 0 ? "Power action" : power.actions[power.pending].label + " this computer?"; color: "#e2eeff"; font.pixelSize: 18; wrapMode: Text.WordWrap}
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Item {Layout.fillWidth: true}
                ForynarchButton {id: keepLogin; text: "Cancel"; onClicked: confirmation.close()}
                ForynarchButton {primary: true; text: power.pending < 0 ? "Confirm" : power.actions[power.pending].label; enabled: power.pending >= 0 && power.actions[power.pending].available; onClicked: power.perform()}
            }
        }
    }
}
