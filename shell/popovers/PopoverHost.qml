import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../logic/popover.js" as Popover
import "../themes"

PopupWindow {
    id: popup

    required property var barWindow

    property Item anchorItem: null
    property var popupState: Popover.popupModel()
    property bool applyingAnchor: false

    visible: popupState.visible
    color: Theme.transparent
    surfaceFormat.opaque: false
    implicitWidth: keyScope.implicitWidth
    implicitHeight: keyScope.implicitHeight
    mask: popupState.interactive ? null : passThrough

    // Rect is in the bar window's logical coordinates. itemRect() is a 0×0 map,
    // so the anchor is measured with contentItem.mapFromItem and the item's size.
    anchor.window: barWindow
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    function motionOptions() {
        return Popover.dismissalMotion(surface ? surface.opacity : 0, {
            instantOpen: Theme.motionOpen === 0,
            instantClose: Theme.motionClose === 0,
        })
    }

    function commit(next) {
        popupState = next
        focusGrab.active = next.grab === true
    }

    function toggle(id, item) {
        const previous = popupState.panelId
        const next = Popover.reducePopup(popupState, { type: "toggle", id: id }, motionOptions())
        if (next.phase === "opening" || next.phase === "open")
            anchorItem = item
        commit(next)
        if (next.phase === "opening" || next.phase === "open") {
            Qt.callLater(function () {
                popup.reposition()
                if (next.panelId !== previous || next.phase === "opening")
                    keyScope.forceActiveFocus()
            })
        }
    }

    function close() {
        commit(Popover.reducePopup(popupState, { type: "close" }, motionOptions()))
    }

    function finishMotion() {
        commit(Popover.reducePopup(popupState, {
            type: "animationFinished",
            opacity: surface.opacity,
        }, motionOptions()))
    }

    function reposition() {
        if (!anchorItem || popupState.phase === "closed")
            return
        anchor.updateAnchor()
    }

    function applyAnchor() {
        if (applyingAnchor || !anchorItem || !barWindow || !barWindow.contentItem || !barWindow.screen)
            return
        applyingAnchor = true
        try {
            const mapped = barWindow.contentItem.mapFromItem(anchorItem, 0, 0, anchorItem.width, anchorItem.height)
            const placed = Popover.anchorFromItemMap(mapped, {
                popupWidth: Math.max(1, keyScope.implicitWidth),
                popupHeight: Math.max(1, keyScope.implicitHeight),
                screenWidth: barWindow.screen.width,
                screenHeight: barWindow.screen.height,
                margin: Theme.panelMargin,
                gap: Theme.panelGap,
                align: "end",
            })
            if (placed) {
                anchor.rect.x = placed.x
                anchor.rect.y = placed.y
                anchor.rect.width = placed.width
                anchor.rect.height = placed.height
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

    Component.onDestruction: focusGrab.active = false
    anchor.onAnchoring: applyAnchor()
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

    Region {
        id: passThrough
        intersection: Intersection.Xor
        item: popup.contentItem
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        onCleared: {
            popup.commit(Popover.reducePopup(popup.popupState, { type: "outside" }, popup.motionOptions()))
            Qt.callLater(function () {
                popup.commit(Popover.reducePopup(popup.popupState, { type: "clearSuppress" }, popup.motionOptions()))
            })
        }
    }

    Item {
        id: keyScope

        focus: popup.popupState.interactive
        implicitWidth: surface.implicitWidth
        implicitHeight: surface.implicitHeight + 4

        Keys.onEscapePressed: function (event) {
            popup.close()
            event.accepted = true
        }

        onImplicitWidthChanged: popup.reposition()
        onImplicitHeightChanged: popup.reposition()

        PopoverSurface {
            id: surface

            opacity: popup.popupState.opacity
            y: popup.popupState.offset

            Behavior on opacity {
                enabled: (popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen) > 0
                NumberAnimation {
                    duration: popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen
                    easing.type: Easing.OutCubic
                    onFinished: popup.finishMotion()
                }
            }

            Behavior on y {
                enabled: (popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen) > 0
                NumberAnimation {
                    duration: popup.popupState.phase === "closing" ? Theme.motionClose : Theme.motionOpen
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                sourceComponent: popup.popupState.panelId === "control"
                    ? controlPanel
                    : popup.popupState.panelId === "calendar" ? calendarPanel : null
                implicitWidth: item ? item.implicitWidth : 0
                implicitHeight: item ? item.implicitHeight : 0
            }
        }
    }

    Component {
        id: calendarPanel
        CalendarPanel {}
    }

    Component {
        id: controlPanel
        ControlCenterPanel {}
    }
}
