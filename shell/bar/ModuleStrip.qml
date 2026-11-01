import QtQuick
import "../components"
import "../themes"
import "../services"
Item {
    id:strip
    required property var barWindow
    property var modules: []
    property real titleWidth: 240
    readonly property real fixedWidth: {
        let total=0,shown=0
        for(let i=0;i<items.count;i++) {
            const item=items.itemAt(i)
            if(item && item.visible) {shown++;if(item.moduleId!=="title")total+=item.width}
        }
        return total+Math.max(0,shown-1)*Theme.moduleSpacing
    }
    implicitWidth:row.implicitWidth
    implicitHeight:Theme.barHeight
    KeyedModel { id:stableModules;entries:strip.modules }
    Row {
        id:row
        spacing:Theme.moduleSpacing
        Repeater {
            id:items
            model:stableModules
            delegate:Loader {
                required property var entry
                readonly property string moduleId:entry
                width:moduleId==="title" ? Math.max(0,strip.titleWidth) : implicitWidth
                visible:moduleId==="title" ? SettingsStore.showFocusedTitle && strip.barWindow.windowTitle!=="" && width>0 : implicitWidth>0
                height:Theme.barHeight
                sourceComponent:strip.barWindow.componentFor(moduleId)
            }
        }
    }
}
