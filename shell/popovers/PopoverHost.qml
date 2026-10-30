import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../logic/popover.js" as Popover
import "../themes"

PopupWindow {
    id: popup

    required property var barWindow

    property string panelId: ""
    property Item anchorItem: null
    property bool wantOpen: false
    property bool shown: false
    property string suppressId: ""
    property bool applyingAnchor: false
    property bool repositioning: false
    property bool blurWarned: false

    visible: shown
    color: Theme.transparent
    surfaceFormat.opaque: false
    implicitWidth: keyScope.implicitWidth
    implicitHeight: keyScope.implicitHeight

    anchor.window: barWindow
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    function toggle(id, item) {
        if (suppressId === id) {
            suppressId = ""
            return
        }
        const next = Popover.reducePopover(shown ? panelId : "", { type: "toggle", id: id })
        if (next.openId === "") {
            close()
            return
        }
        const switching = shown && wantOpen && panelId !== ""
        panelId = next.openId
        anchorItem = item
        if (switching) {
            Qt.callLater(function () {
                reposition()
                keyScope.forceActiveFocus()
            })
            return
        }
        open()
    }

    function open() {
        shown = true
        wantOpen = false
        Qt.callLater(function () {
            reposition()
            wantOpen = true
            focusGrab.active = true
            keyScope.forceActiveFocus()
            attachBlur()
        })
    }

    function close() {
        wantOpen = false
        focusGrab.active = false
        clearBlur()
        if (Theme.motionClose === 0)
            finishClose()
    }

    function finishClose() {
        if (wantOpen)
            return
        shown = false
        panelId = ""
    }

    function reposition() {
        if (repositioning)
            return
        repositioning = true
        try {
            anchor.updateAnchor()
        } finally {
            repositioning = false
        }
    }

    function applyAnchor() {
        if (applyingAnchor || !anchorItem || !barWindow)
            return
        applyingAnchor = true
        let itemRect = null
        try {
            itemRect = barWindow.itemRect(anchorItem)
        } catch (error) {
            itemRect = null
        }
        if (!itemRect || itemRect.width === undefined) {
            applyingAnchor = false
            return
        }
        const screen = barWindow.screen
        const placed = Popover.placePopup({
            anchorX: itemRect.x,
            anchorY: itemRect.y + itemRect.height + Theme.panelGap,
            anchorWidth: itemRect.width,
            popupWidth: Math.max(1, keyScope.implicitWidth),
            popupHeight: Math.max(1, keyScope.implicitHeight),
            screenWidth: screen && screen.width ? screen.width : barWindow.width,
            screenHeight: screen && screen.height ? screen.height : 0,
            margin: Theme.panelMargin,
            align: "end"
        })
        anchor.rect.x = placed.x
        anchor.rect.y = placed.y
        anchor.rect.width = 1
        anchor.rect.height = 1
        applyingAnchor = false
    }

    function noteBlurUnavailable() {
        if (blurWarned)
            return
        blurWarned = true
        console.warn("SwiftShell: panel blur is unavailable; the scrim remains")
    }

    function attachBlur() {
        if (Theme.panelBlur <= 0) {
            clearBlur()
            return
        }
        try {
            const effect = popup["BackgroundEffect"]
            if (!effect) {
                noteBlurUnavailable()
                return
            }
            effect.blurRegion = blurRegion
        } catch (error) {
            noteBlurUnavailable()
        }
    }

    function clearBlur() {
        try {
            const effect = popup["BackgroundEffect"]
            if (effect)
                effect.blurRegion = null
        } catch (error) {
            // This Quickshell build has no background-effect attachment.
        }
    }

    anchor.onAnchoring: applyAnchor()
    onClosed: finishClose()

    Region {
        id: blurRegion
        item: popup.contentItem
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup]
        onCleared: {
            popup.suppressId = popup.panelId
            popup.close()
            Qt.callLater(function () { popup.suppressId = "" })
        }
    }

    Item {
        id: keyScope

        focus: popup.shown
        implicitWidth: surface.implicitWidth
        implicitHeight: surface.implicitHeight + 4

        Keys.onEscapePressed: function (event) {
            popup.close()
            event.accepted = true
        }

        onImplicitWidthChanged: {
            if (popup.shown)
                popup.reposition()
        }
        onImplicitHeightChanged: {
            if (popup.shown)
                popup.reposition()
        }

        PopoverSurface {
            id: surface

            opacity: popup.wantOpen ? 1 : 0
            y: popup.wantOpen ? 4 : 0

            Behavior on opacity {
                enabled: (popup.wantOpen ? Theme.motionOpen : Theme.motionClose) > 0
                NumberAnimation {
                    duration: popup.wantOpen ? Theme.motionOpen : Theme.motionClose
                    easing.type: Easing.OutCubic
                    onFinished: {
                        if (!popup.wantOpen && surface.opacity === 0)
                            popup.finishClose()
                    }
                }
            }

            Behavior on y {
                enabled: (popup.wantOpen ? Theme.motionOpen : Theme.motionClose) > 0
                NumberAnimation {
                    duration: popup.wantOpen ? Theme.motionOpen : Theme.motionClose
                    easing.type: Easing.OutCubic
                }
            }

            Loader {
                id: panelLoader

                sourceComponent: popup.panelId === "control" ? controlPanel : calendarPanel
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
