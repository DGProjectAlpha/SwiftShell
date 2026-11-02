import QtQuick
import Quickshell.Services.SystemTray
import "../components"
import "../themes"

Column {
    id:root
    property var hostWindow:null
    property var trayModel:SystemTray.items
    spacing:Theme.panelSpacing
    width:parent ? parent.width : Theme.controlWidth
    SectionHeader {width:parent.width;text:"Tray"}
    ServiceStatus {visible:items.count===0;name:"Tray";detail:"No tray applications"}
    Repeater {
        id:items
        model:root.trayModel
        delegate:TrayItemControl {
            required property var modelData
            entry:modelData
            hostWindow:root.hostWindow
            showLabel:true
            width:root.width
            textPrimary:Theme.settingsText
        }
    }
}
