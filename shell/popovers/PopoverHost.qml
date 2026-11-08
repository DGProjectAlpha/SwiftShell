import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../logic/popover.js" as Popover
import "../themes"
import "../components"
import "../services"
import "../notifications"
import "../clipboard"

PanelWindow {
    id: popup

    required property var barWindow

    readonly property bool surfaceBlurApplied:backdrop.applied
    readonly property var blurBounds:({width:backdrop.surface ? backdrop.surface.width : 0,height:backdrop.surface ? backdrop.surface.height : 0})
    property Component customPanel: null
    property Item anchorItem: null
    property var popupState: Popover.popupModel()
    property bool applyingAnchor: false
    property bool readyToShow: false
    property int showTicket: 0
    property string requestedClockTab:"clock"

    visible: popupState.visible && readyToShow
    color: Theme.transparent
    surfaceFormat.opaque: false
    implicitWidth: Math.ceil(keyScope.implicitWidth)
    implicitHeight: Math.ceil(keyScope.implicitHeight)
    mask: popupState.interactive ? cardInput : passThrough

    // Independent layer surfaces support real background effects on Hyprland;
    // each floater owns its rounded blur region, placement, and keyboard focus.
    screen:barWindow ? barWindow.screen : null
    exclusionMode:ExclusionMode.Ignore
    anchors { top:true;left:true }
    property point placement:Qt.point(0,0)
    margins.left:Math.round(placement.x)
    margins.top:Math.round(placement.y)
    WlrLayershell.namespace:"swiftshell-popover"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:popup.popupState.interactive && visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function geometry() {
        return {x:popup.screen ? popup.screen.x+Math.round(popup.placement.x) : 0,y:popup.screen ? popup.screen.y+Math.round(popup.placement.y) : 0,width:popup.width,height:popup.height,
            details:bodyLoader.item && bodyLoader.item.diagnostics ? bodyLoader.item.diagnostics() : null,items:bodyLoader.item && bodyLoader.item.geometry ? bodyLoader.item.geometry() : []}
    }
    function lifecycleDiagnostics() {
        return {phase:popupState.phase,opacity:panelSurface.opacity,grab:focusGrab.active,interactive:popupState.interactive}
    }

    function motionOptions() {
        return Popover.dismissalMotion(panelSurface ? panelSurface.opacity : 0, {
            instantOpen: Theme.motionOpen === 0,
            instantClose: Theme.motionClose === 0,
        })
    }

    function commit(next) {
        const step = Popover.focusTransition(popupState, next);
        if (step.clearFocusBeforeGrab || !step.takeFocus)
            keyScope.focus = false;
        if(!next.visible) {readyToShow=false;showTicket++}
        popupState = next;
        focusGrab.active = step.grab === true && readyToShow;
        keyScope.focus = step.takeFocus;
    }

    function toggle(id, item) {
        const next=Popover.reducePopup(popupState,{type:"toggle",id:id},motionOptions())
        const opening=next.phase === "opening" || next.phase === "open"
        if(opening) {anchorItem=item;readyToShow=false}
        commit(next)
        if(!opening) return
        const ticket=++showTicket
        Qt.callLater(function() {
            if(ticket!==showTicket || !popup.popupState.visible) return
            panelSurface.prepareLayout()
            popup.reposition()
            readyToShow=true
            focusGrab.active=popup.popupState.grab === true
            Qt.callLater(function() {if(popup.visible && popup.popupState.interactive){if(popup.popupState.panelId==="notifications" && bodyLoader.item && bodyLoader.item.focusReply && bodyLoader.item.focusReply())return;if(popup.popupState.panelId==="clipboard" && bodyLoader.item && bodyLoader.item.focusSearch){bodyLoader.item.focusSearch();return}keyScope.forceActiveFocus()}})
        })
    }

    function openClock(tab,item) {
        requestedClockTab=["calendar","timer","stopwatch"].indexOf(tab)>=0 ? tab : "clock"
        if(popupState.visible && popupState.panelId==="calendar" && bodyLoader.item) {
            if(bodyLoader.item.activeTab===requestedClockTab) {close();return}
            bodyLoader.item.showTab(requestedClockTab)
            anchorItem=item
            Qt.callLater(function(){panelSurface.prepareLayout();popup.reposition()})
            return
        }
        toggle("calendar",item)
    }

    function close() {
        commit(Popover.reducePopup(popupState, { type: "close" }, motionOptions()))
    }

    function finishMotion() {
        commit(Popover.reducePopup(popupState, {
            type: "animationFinished",
            opacity: panelSurface.opacity,
        }, motionOptions()))
    }

    function reposition() {
        if (!anchorItem || popupState.phase === "closed")
            return
        applyAnchor()
    }

    function applyAnchor() {
        if (applyingAnchor || !anchorItem || !barWindow || !barWindow.contentItem || !barWindow.screen)
            return
        applyingAnchor = true
        try {
            const mapped = barWindow.contentItem.mapFromItem(anchorItem, 0, 0, anchorItem.width, anchorItem.height)
            const materialAnchor={x:mapped.x+panelSurface.shadowMargin,y:mapped.y-panelSurface.shadowMargin,width:mapped.width,height:mapped.height}
            const placed = Popover.anchorFromItemMap(materialAnchor, {
                popupWidth: Math.max(1, popup.implicitWidth),
                popupHeight: Math.max(1, popup.implicitHeight),
                screenWidth: barWindow.screen.width,
                screenHeight: barWindow.screen.height,
                margin: Theme.panelMargin,
                gap: Theme.panelGap,
                align: "end",
            })
            if (placed) {
                const gap=Theme.panelGap, margin=Theme.panelMargin
                if(barWindow.edge==="bottom")placed.y=barWindow.screen.height-barWindow.height-popup.implicitHeight-gap
                if(barWindow.vertical) {
                    placed.x=barWindow.edge==="left" ? barWindow.width+gap : barWindow.screen.width-barWindow.width-popup.implicitWidth-gap
                    placed.y=Math.max(margin,Math.min(mapped.y,popup.screen.height-popup.implicitHeight-margin))
                }
                popup.placement=Qt.point(Math.max(margin,placed.x),Math.max(margin,placed.y))
            }
        } finally {
            applyingAnchor = false
        }
    }

    function noteScreen() {
        if (!barWindow || barWindow.screen === null || barWindow.screen === undefined) {
            commit(Popover.reducePopup(popupState, { type: "monitorLost" }, motionOptions()))
            return
        }
        if (popupState.phase !== "closed")
            reposition()
    }

    Component.onDestruction: {
        keyScope.focus = false
        focusGrab.active = false
    }
    onClosed: commit(Popover.reducePopup(popupState, { type: "destroy" }, motionOptions()))

    onAnchorItemChanged: {
        if (anchorItem === null && popupState.phase !== "closed")
            commit(Popover.reducePopup(popupState, { type: "anchorLost" }, motionOptions()))
    }

    Connections {
        target: popup.barWindow
        function onScreenChanged() { popup.noteScreen() }
        function onWidthChanged() { popup.reposition() }
        function onHeightChanged() { popup.reposition() }
    }

    Connections {
        target: popup.anchorItem
        function onXChanged() { popup.reposition() }
        function onYChanged() { popup.reposition() }
        function onWidthChanged() { popup.reposition() }
        function onHeightChanged() { popup.reposition() }
    }

    Connections {
        target:LauncherModel
        function onOpenChanged() {if(LauncherModel.open)popup.close()}
    }

    Connections {
        target:SettingsModel
        function onOpenChanged() { if(SettingsModel.open) popup.close() }
    }

    Region {id:cardInput;item:panelSurface.blurSurface;radius:Theme.radius}
    Region {
        id: passThrough
        intersection: Intersection.Xor
        item: popup.contentItem
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup,popup.barWindow]
        onCleared: {
            popup.commit(Popover.reducePopup(popup.popupState, { type: "outside" }, popup.motionOptions()))
            Qt.callLater(function () {
                popup.commit(Popover.reducePopup(popup.popupState, { type: "clearSuppress" }, popup.motionOptions()))
            })
        }
    }

    MouseArea {
        z:-1
        anchors.fill:parent
        acceptedButtons:Qt.LeftButton | Qt.RightButton
        onClicked:popup.close()
    }

    BackdropEffect {
        id:backdrop
        targetWindow:popup
        surface:panelSurface.blurSurface
        cornerRadius:Theme.radius
        enabled:popup.visible && panelSurface.opacity>0.001 && SettingsStore.panelBlur>0
    }

    Item {
        id: keyScope

        focus: false
        activeFocusOnTab: false
        implicitWidth: panelSurface.implicitWidth
        implicitHeight: panelSurface.implicitHeight + 4

        Keys.onEscapePressed: function (event) {
            popup.close()
            event.accepted = true
        }

        Keys.onPressed:function(event) {
            const alt=(event.modifiers & Qt.AltModifier)!==0
            if(event.key===Qt.Key_PageDown || (alt && event.key===Qt.Key_J)) panelSurface.scrollBy(Theme.controlHeight*4)
            else if(event.key===Qt.Key_PageUp || (alt && event.key===Qt.Key_K)) panelSurface.scrollBy(-Theme.controlHeight*4)
            else return
            event.accepted=true
        }

        onImplicitWidthChanged: popup.reposition()
        onImplicitHeightChanged: popup.reposition()

        PopoverSurface {
            id: panelSurface
            maximumHeight:popup.barWindow && popup.barWindow.screen ? popup.barWindow.screen.height-Theme.barHeight-Theme.panelGap-Theme.panelMargin*2 : 10000

            opacity: popup.popupState.opacity
            // Animation.finished is not emitted for animations inside Behavior.
            // Observe the rendered endpoint instead, including zero-duration
            // transitions, so an invisible window cannot retain its blur region.
            onOpacityChanged: {
                if(Math.abs(opacity-popup.popupState.opacity)<=0.001)
                    Qt.callLater(popup.finishMotion)
            }
            // Open downward and retract upward; keep the established open
            // position. Closing already releases keyboard, grab and input mask.
            y: popup.popupState.offset === 0 ? -8 : popup.popupState.offset

            Behavior on opacity {
                enabled: (popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen) > 0
                NumberAnimation {
                    duration: popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                enabled: (popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen) > 0
                NumberAnimation {
                    duration: popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen
                    easing.type: Easing.OutCubic
                }
            }

            // Loader adopts the loaded item's implicit size. Assigning
            // implicitWidth or implicitHeight here is a startup error.
            Loader {
                id:bodyLoader
                onLoaded:if(popup.popupState.panelId==="calendar" && item.showTab)item.showTab(popup.requestedClockTab)
                sourceComponent: popup.popupState.panelId === "weather" ? weatherPanel : popup.popupState.panelId === "performance" ? performancePanel : popup.popupState.panelId === "clipboard" ? clipboardPanel : popup.popupState.panelId === "notifications" ? notificationPanel : popup.popupState.panelId === "control"
                    ? controlPanel
                    : popup.popupState.panelId === "network" ? networkPanel : popup.popupState.panelId === "power" ? powerPanel : popup.popupState.panelId === "calendar" ? calendarPanel : popup.popupState.panelId === "customize" ? popup.customPanel : null
            }
        }
    }

    Component {
        id: calendarPanel
        CalendarPanel {}
    }

    Component {id:notificationPanel;NotificationDrawer {reading:popup.visible;onSettingsRequested:{popup.close();SettingsStore.setSettingsCategory("notifications");SettingsModel.show(popup.barWindow.monitorKey)}}}
    Component {id:weatherPanel;WeatherPanel {onSettingsRequested:{popup.close();SettingsStore.setSettingsCategory("weather");SettingsModel.show(popup.barWindow.monitorKey)}}}
    Component {id:performancePanel;PerformancePanel {}}
    Component {id:clipboardPanel;ClipboardPanel {onDetached:popup.close();onDismissed:popup.close()}}
    Component {id:networkPanel;NetworkPanel {onSettingsRequested:{popup.close();SettingsStore.setSettingsCategory("network");SettingsModel.show(popup.barWindow.monitorKey)}}}
    Component {id:powerPanel;PowerPanel {onSettingsRequested:{popup.close();SettingsStore.setSettingsCategory("power");SettingsModel.show(popup.barWindow.monitorKey)}}}
    Component {
        id: controlPanel
        AudioPanel {onSettingsRequested:{popup.close();SettingsStore.setSettingsCategory("audio");SettingsModel.show(popup.barWindow.monitorKey)}}
    }
}
