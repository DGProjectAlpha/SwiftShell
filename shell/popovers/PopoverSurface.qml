import QtQuick
import QtQuick.Controls.Basic as Controls
import "../services"
import "../themes"
Item {
    id:root
    default property alias content:body.data
    property alias blurSurface:card
    property real maximumHeight:10000
    readonly property int shadowMargin:Theme.surfaceShadowInset
    implicitWidth:card.width+shadowMargin*2
    implicitHeight:card.height+shadowMargin*2
    function prepareLayout() {
        function layout(item) {
            for(let i=0;i<item.children.length;i++) layout(item.children[i])
            if(typeof item.forceLayout === "function") item.forceLayout()
        }
        layout(body)
        viewport.contentY=0
    }
    function scrollBy(delta) { viewport.contentY=Math.max(0,Math.min(viewport.contentHeight-viewport.height,viewport.contentY+delta)) }
    function reveal(item) {
        let ancestor=item
        while(ancestor && ancestor!==body) ancestor=ancestor.parent
        if(!ancestor || !item) return
        const mapped=item.mapToItem(body,0,0,item.width,item.height)
        if(mapped.y<viewport.contentY) viewport.contentY=mapped.y
        else if(mapped.y+mapped.height>viewport.contentY+viewport.height) viewport.contentY=mapped.y+mapped.height-viewport.height
    }
    Connections {
        target:root.Window.window
        function onActiveFocusItemChanged() { const window=root.Window.window;if(window)root.reveal(window.activeFocusItem) }
    }
    Loader {
        anchors.fill:card
        source:"../components/SurfaceShadow.qml"
        visible:Theme.shadowOpacity>0
    }
    Rectangle {
        id:card
        x:root.shadowMargin;y:root.shadowMargin
        width:body.implicitWidth+Theme.panelPadding*2
        height:viewport.height+Theme.panelPadding*2
        radius:Theme.radius
        color:Theme.floaterSurface
        MouseArea {anchors.fill:parent;onClicked:function(){}}
        Flickable {
            id:viewport
            objectName:"popoverScroll"
            x:Theme.panelPadding;y:Theme.panelPadding
            width:body.implicitWidth
            height:Math.min(body.implicitHeight,Math.max(1,root.maximumHeight-Theme.panelPadding*2-root.shadowMargin*2))
            contentWidth:body.implicitWidth;contentHeight:body.implicitHeight
            clip:true
            boundsBehavior:Flickable.StopAtBounds
            Controls.ScrollBar.vertical:Controls.ScrollBar {
                width:4
                policy:viewport.contentHeight>viewport.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
                contentItem:Rectangle {radius:2;color:Theme.settingsMuted;opacity:parent.active ? .7 : .3}
                background:Item {}
            }
            Column {
                id:body
                objectName:"popoverBody"
                spacing:Theme.panelSpacing
            }
        }
    }
}
