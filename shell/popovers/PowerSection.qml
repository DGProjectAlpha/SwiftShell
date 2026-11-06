import QtQuick
import Quickshell
import "../components"
import "../logic/launcher.js" as Launcher
import "../themes"
import "../services"

Column {
    id: root

    spacing: Theme.panelSpacing
    width: parent ? parent.width : Theme.controlWidth
    property string heading:"Session"
    property string confirmId: ""
    Component.onCompleted:SessionActions.refresh()

    SectionHeader {
        width: parent.width
        text: root.heading
    }

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Lock immediately, or choose another action and confirm."
        color: Theme.settingsMuted
        font.family: Theme.settingsFontFamily
        font.pixelSize: Theme.settingsFontSizeSmall
    }

    Repeater {
        model: Launcher.POWER

        delegate: FlatButton {
            required property var modelData
            objectName:"session-action-"+modelData.id
            enabled:!SessionActions.busy && SessionActions.available(modelData.id)
            Accessible.description:SessionActions.reason(modelData.id)
            label: root.confirmId === modelData.id ? "Confirm " + modelData.label : modelData.label
            emphasized: root.confirmId === modelData.id
            onActivated: {
                const step=Launcher.powerInvocation(root.confirmId,modelData.id)
                root.confirmId=step.confirmId
                if(step.run)SessionActions.perform(step.action)
            }
        }
    }

    Text {
        width:parent.width
        visible:SessionActions.ready && !SessionActions.available("lock")
        text:SessionActions.reason("lock")
        wrapMode:Text.WordWrap;color:Theme.settingsMuted
        font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
    }
    FlatButton {visible:SessionActions.error!=="";label:"Retry session check";enabled:!SessionActions.busy && !SessionActions.refreshing;onActivated:SessionActions.refresh()}
    Text {
        visible:text!==""
        width: parent.width
        wrapMode: Text.WordWrap
        objectName:"sessionActionStatus"
        textFormat:Text.PlainText
        text:SessionActions.error || SessionActions.notice
        color: Theme.settingsText
        font.family: Theme.settingsFontFamily
        font.pixelSize: Theme.settingsFontSizeSmall
    }
}
