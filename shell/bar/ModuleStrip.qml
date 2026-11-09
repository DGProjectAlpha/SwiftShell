import QtQuick
import "../components"
import "../themes"
import "../services"
import "../logic/bar.js" as Bar
Item {
    id:strip
    required property var barWindow
    readonly property var barMetrics:barWindow.barMetrics || Theme.barMetrics
    property var modules: []
    property real titleWidth: 240
    function renderingGeometry() {
        const out=[]
        for(let i=0;i<items.count;i++) {
            const item=items.itemAt(i)
            if(item && item.visible){const target=item.renderedItem || item,p=target.mapToItem(strip.barWindow.contentItem,0,0);out.push({id:item.moduleId,x:p.x,y:p.y})}
        }
        return out
    }
    readonly property int layoutCount: {
        let count=0
        for(let i=0;i<items.count;i++) {
            const item=items.itemAt(i)
            if(item && item.participatesInLayout)count++
        }
        return count
    }
    readonly property real fixedWidth: {
        let total=0,shown=0
        for(let i=0;i<items.count;i++) {
            const item=items.itemAt(i)
            if(item && item.participatesInLayout) {shown++;if(item.moduleId!=="title")total+=item.width}
        }
        return total+Math.max(0,shown-1)*barMetrics.moduleSpacing
    }
    implicitWidth:strip.barWindow.vertical ? strip.barWindow.railWidth : row.implicitWidth
    implicitHeight:row.implicitHeight
    KeyedModel { id:stableModules;entries:strip.modules }
    Grid {
        id:row
        columns:strip.barWindow.vertical ? 1 : Math.max(1,strip.layoutCount)
        spacing:strip.barMetrics.moduleSpacing
        Repeater {
            id:items
            model:stableModules
            delegate:Item {
                id:moduleFrame
                required property var entry
                readonly property string moduleId:entry
                readonly property Item renderedItem:moduleLoader.item
                implicitWidth:moduleLoader.implicitWidth
                implicitHeight:moduleLoader.implicitHeight
                width:strip.barWindow.vertical ? strip.barWindow.railWidth : moduleId==="title" ? Math.max(0,strip.titleWidth) : implicitWidth
                readonly property bool participatesInLayout:moduleId==="title" ? strip.barWindow.outputLayout.showFocusedTitle && strip.barWindow.windowTitle!=="" && width>0 : implicitWidth>0
                visible:participatesInLayout
                height:Math.max(strip.barMetrics.height,implicitHeight)
                Loader {
                    id:moduleLoader
                    width:moduleFrame.width;height:moduleFrame.height
                    x:Bar.snapModulePosition(strip.x+row.x+moduleFrame.x,strip.barWindow.devicePixelRatio,strip.barWindow.contentScale)-(strip.x+row.x+moduleFrame.x)
                    y:Bar.snapModulePosition(strip.y+row.y+moduleFrame.y,strip.barWindow.devicePixelRatio,strip.barWindow.contentScale)-(strip.y+row.y+moduleFrame.y)
                    sourceComponent:strip.barWindow.componentFor(moduleFrame.moduleId)
                }
            }
        }
    }
}
