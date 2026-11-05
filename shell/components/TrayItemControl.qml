import QtQuick
import Quickshell
import "../logic/tray.js" as Tray
import "../themes"

MouseArea {
    id:control
    property var entry:null
    property var hostWindow:null
    property bool showLabel:false
    property color textPrimary:Theme.textPrimary
    readonly property string itemTitle:Tray.itemTitle(entry)
    readonly property string itemIcon:entry && typeof entry.icon==="string" ? entry.icon : ""
    readonly property bool menuAvailable:entry && entry.hasMenu===true
    readonly property bool needsAttention:entry && entry.status===2
    readonly property bool menuOpen:themedMenu.opened
    readonly property var menuWindow:themedMenu.nativeWindow
    function menuDiagnostics(){return themedMenu.diagnostics()}
    TrayMenu {id:themedMenu;hostWindow:control.hostWindow;anchorItem:control}
    signal invoked(string action)
    implicitWidth:showLabel ? Math.max(160,label.implicitWidth+Theme.barIcon+24) : Theme.barIcon
    implicitHeight:showLabel ? Theme.controlHeight : Theme.barHeight
    width:implicitWidth;height:implicitHeight
    acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton
    enabled:entry!==null && !(entry.onlyMenu===true && !menuAvailable)
    hoverEnabled:true;activeFocusOnTab:true
    cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    Accessible.role:Accessible.Button
    Accessible.name:itemTitle
    Accessible.description:menuAvailable ? "Right-click or press Menu for application actions" : "Activate tray application"
    function showMenu() {
        if(!entry || !menuAvailable || !hostWindow || !hostWindow.contentItem)return false
        const point=mapToItem(hostWindow.contentItem,width/2,height)
        try {
            if(entry.menu !== undefined && entry.menu) {
                if(!themedMenu.open(entry.menu,itemTitle))return false
            } else entry.display(hostWindow,Math.round(point.x),Math.round(point.y))
            invoked("menu")
            return true
        } catch(error) { return false }
    }
    function activate(button) {
        if(!entry)return false
        if(button===Qt.RightButton || entry.onlyMenu===true)return showMenu()
        try {
            if(button===Qt.MiddleButton) {entry.secondaryActivate();invoked("secondary")}
            else {entry.activate();invoked("activate")}
            return true
        } catch(error) {return false}
    }
    onMenuAvailableChanged:if(!menuAvailable)themedMenu.close()
    onEntryChanged:themedMenu.close()
    onClicked:function(mouse){activate(mouse.button)}
    onWheel:function(wheel) {
        if(!entry)return
        const horizontal=Math.abs(wheel.angleDelta.x)>Math.abs(wheel.angleDelta.y)
        const delta=horizontal ? wheel.angleDelta.x : wheel.angleDelta.y
        if(!delta)return
        try {entry.scroll(delta,horizontal);invoked("scroll");wheel.accepted=true} catch(error){wheel.accepted=false}
    }
    Keys.onPressed:function(event) {
        if(event.key===Qt.Key_Menu || (event.key===Qt.Key_F10 && (event.modifiers&Qt.ShiftModifier)))event.accepted=showMenu()
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space)event.accepted=activate(Qt.LeftButton)
    }
    Rectangle {
        anchors.fill:parent;anchors.margins:showLabel ? 1 : 0
        radius:Theme.controlRadius
        color:showLabel && control.containsMouse ? Theme.settingsHover : "transparent"
        border.width:control.activeFocus ? 1 : 0
        border.color:control.textPrimary
    }
    Image {
        id:icon
        x:control.showLabel ? 6 : (parent.width-width)/2
        anchors.verticalCenter:parent.verticalCenter
        width:Theme.barIcon;height:Theme.barIcon
        source:control.itemIcon
        fillMode:Image.PreserveAspectFit
        cache:true
    }
    Text {
        x:icon.x;width:icon.width;height:icon.height
        anchors.verticalCenter:parent.verticalCenter
        visible:control.itemIcon==="" || icon.status===Image.Error
        text:control.itemTitle.charAt(0)
        textFormat:Text.PlainText
        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
        color:control.textPrimary;font.family:Theme.fontFamily;font.pixelSize:Theme.fontSizeSmall
    }
    Text {
        id:label
        visible:control.showLabel
        anchors.left:icon.right;anchors.leftMargin:10
        anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter
        text:control.itemTitle;textFormat:Text.PlainText;elide:Text.ElideRight
        color:control.textPrimary;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
    }
    Rectangle {
        visible:control.needsAttention
        width:3;height:3;radius:1.5
        anchors.right:icon.right;anchors.bottom:icon.bottom
        color:control.textPrimary
    }
}
