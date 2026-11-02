import QtQuick
import Quickshell.Services.SystemTray
import "../components"
import "../themes"

Item {
    id:root
    property var hostWindow:null
    property var trayModel:SystemTray.items
    property color textPrimary:Theme.textPrimary
    property color textMuted:Theme.textMuted
    readonly property int itemCount:items.count
    implicitWidth:items.count ? row.implicitWidth : 0
    implicitHeight:Theme.barHeight
    visible:items.count>0
    function geometry() {
        const result=[]
        for(let index=0;index<items.count;index++) {
            const item=items.itemAt(index),point=item.mapToItem(null,0,0)
            result.push({index:index,id:item.entry ? item.entry.id : "",hasMenu:item.menuAvailable,menuOpen:item.menuOpen,x:point.x,y:point.y,width:item.width,height:item.height})
        }
        return result
    }
    Row {
        id:row
        anchors.verticalCenter:parent.verticalCenter
        spacing:4
        Repeater {
            id:items
            objectName:"trayItems"
            // Keep native objects and ObjectModel notifications. Snapshotting
            // icons/menu readiness would leave stale controls after registration.
            model:root.trayModel
            delegate:TrayItemControl {
                required property var modelData
                entry:modelData
                hostWindow:root.hostWindow
                textPrimary:root.textPrimary
            }
        }
    }
}
