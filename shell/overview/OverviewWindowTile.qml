import QtQuick
import Quickshell
import "../services"
import "../themes"
import "../logic/overview.js" as Overview
Rectangle {
    id:root
    required property var windowData
    required property var monitor
    property real desktopWidth:parent.width
    property real desktopHeight:parent.height
    readonly property var frame:Overview.windowFrame(windowData.geometry,monitor,desktopWidth,desktopHeight)
    x:frame.x;y:frame.y;width:frame.width;height:frame.height
    radius:Math.max(2,Theme.radius*.35)
    color:Theme.settingsSelected
    border.width:mouse.containsMouse || root.activeFocus ? 2 : 0
    border.color:Theme.settingsText
    clip:true
    activeFocusOnTab:true
    objectName:"overviewWindowTile"
    readonly property bool previewReady:preview.item!==null && preview.item.hasContent===true
    signal activated()
    Keys.onReturnPressed:activated()
    Keys.onSpacePressed:activated()
    Loader {
        id:preview
        anchors.fill:parent
        active:OverviewService.open && root.windowData.handle!==null
        source:active ? "OverviewPreview.qml" : ""
        onLoaded:item.captureSource=Qt.binding(function(){return root.windowData.handle})
    }
    Text {
        anchors.centerIn:parent;width:parent.width-12
        visible:!root.previewReady
        text:root.windowData.title + (root.height>55 ? "\nPreview unavailable" : "")
        font.family:Theme.fontFamily;font.pixelSize:Theme.fontSizeSmall
        color:Theme.settingsMuted;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter
    }
    Rectangle {
        anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
        height:Math.min(parent.height,26);color:Theme.settingsPopupSurface
        visible:mouse.containsMouse || root.activeFocus
        Text {anchors.fill:parent;anchors.margins:4;text:root.windowData.title;elide:Text.ElideRight;color:Theme.settingsText;font.pixelSize:11}
    }
    MouseArea {id:mouse;anchors.fill:parent;hoverEnabled:true;onClicked:root.activated()}
}
