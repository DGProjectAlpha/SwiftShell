import QtQuick
import "../services"
import "../themes"
Rectangle {
    id:root
    required property var workspace
    required property var monitor
    property bool selected:false
    readonly property var windows:OverviewService.windows.filter(function(w){return w.workspace===root.workspace.key})
    readonly property alias desktop:desktop
    signal activated()
    color:"transparent"
    objectName:"overviewWorkspace"
    Text {
        id:title
        width:parent.width;height:30
        text:root.workspace.name+(root.workspace.active ? " · Current" : "")
        color:root.selected ? Theme.settingsText : Theme.settingsMuted
        font.family:Theme.fontFamily;font.pixelSize:Theme.fontSize
        font.weight:root.selected ? Font.DemiBold : Font.Normal
        elide:Text.ElideRight
    }
    Rectangle {
        id:desktop
        anchors.left:parent.left;anchors.right:parent.right;anchors.top:title.bottom;anchors.bottom:parent.bottom
        radius:Math.max(3,Theme.radius*.65)
        color:Theme.floaterSurface
        border.width:root.selected ? 1 : 0;border.color:Theme.settingsMuted
        clip:true
        MouseArea {anchors.fill:parent;onClicked:root.activated()}
        Text {anchors.centerIn:parent;visible:root.windows.length===0;text:"Empty workspace";color:Theme.settingsMuted;font.pixelSize:Theme.fontSizeSmall}
        Repeater {
            model:root.windows
            delegate:OverviewWindowTile {
                required property var modelData
                windowData:modelData;monitor:root.monitor
                onActivated:OverviewService.chooseWindow(windowData)
            }
        }
    }
}
