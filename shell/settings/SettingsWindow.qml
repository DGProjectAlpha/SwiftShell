import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Controls as ControlTypes
import "../logic/settingsFocus.js" as Focus
import Quickshell
import "."
import "../components"
import "../logic/settings.js" as Settings
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

FloatingWindow {
    id: window
    title: "SwiftShell Settings"
    visible: SettingsModel.open
    color: "transparent"
    // The shadow is visual only; resize targets follow the painted window.
    mask: Region { item:content }
    minimumSize: Qt.size(640,440)
    property int initialWidth: 1000
    property int initialHeight: 700
    implicitWidth: initialWidth
    implicitHeight: initialHeight
    property bool closing: false
    property int mapAttempts: 0
    property bool placementReady: false
    property int resizeRequests: 0
    property bool lastResizeAccepted: false
    readonly property int shadowInset: WindowService.maximized ? 0 : Theme.surfaceShadowInset
    property var gestureBaseline:null
    property var history: Settings.initialHistory(window.currentAppearance())
    readonly property bool canUndo: history && history.past && history.past.length > 0

    function currentAppearance() {
        return {
            mode: SettingsStore.appearanceMode,
            accentColor:SettingsStore.accentColor,
            opaqueWindows:SettingsStore.opaqueWindows,
            tint: SettingsStore.appearanceTint,
            panelOpacity: SettingsStore.panelOpacity,
            panelBlur: SettingsStore.panelBlur,
            radius: SettingsStore.radius,
            shadowOpacity: SettingsStore.shadowOpacity,
            shadowSoftness: SettingsStore.shadowSoftness,
            motionScale: SettingsStore.motionScale,
            reducedMotion: SettingsStore.reducedMotion,
            panelPadding: SettingsStore.panelPadding,
            panelSpacing: SettingsStore.panelSpacing,
            fontSize: SettingsStore.fontSize,
            fontWeight: SettingsStore.fontWeight,
            iconScale: SettingsStore.iconScale,
            topGradient: SettingsStore.topGradient,
            contrast: SettingsStore.textContrast,
            automaticText: SettingsStore.automaticText,
            automaticGradient: SettingsStore.automaticGradient,
            manualText: SettingsStore.manualText,
            manualMuted: SettingsStore.manualMuted,
            manualPanel: SettingsStore.manualPanel,
            manualGradient: SettingsStore.manualGradient
        }
    }

    function applyHistory(next) {
        history = next
        SettingsStore.setAppearance(history.present)
    }

    function beginAppearanceGesture() {
        if(gestureBaseline===null)gestureBaseline=Settings.initialHistory(window.currentAppearance()).present
    }
    function endAppearanceGesture() {
        if(gestureBaseline===null)return
        const current=Settings.initialHistory(window.currentAppearance()).present
        if(JSON.stringify(current)!==JSON.stringify(gestureBaseline)) {
            const past=history.past.slice();past.push(gestureBaseline)
            if(past.length>20)past.shift()
            history={past:past,present:current}
        }
        gestureBaseline=null
    }
    function commit(patch) {
        const baseline=Settings.initialHistory(window.currentAppearance()).present
        const present=Settings.initialHistory(baseline).present
        Object.keys(patch).forEach(function(key){present[key]=patch[key]})
        if(gestureBaseline!==null) {
            const next=Settings.initialHistory(present).present
            history={past:history.past,present:next}
            SettingsStore.setAppearance(next)
        } else window.applyHistory(Settings.reduceAppearanceHistory({past:history.past,present:baseline},{type:"edit",present:present}))
    }
    function undo() {
        window.endAppearanceGesture()
        window.applyHistory(Settings.reduceAppearanceHistory(history,{type:"undo"}))
    }
    function resetAppearance() {resetConfirm.open()}
    function confirmResetAppearance() {
        window.endAppearanceGesture()
        window.applyHistory(Settings.reduceAppearanceHistory({past:history.past,present:Settings.initialHistory(window.currentAppearance()).present},{type:"reset"}))
        resetConfirm.close()
    }

    readonly property bool searchHasFocus: search.activeFocus
    readonly property int pageStatus: pageLoader.status
    function activePage() { return pageLoader.item }
    function setAllSectionsExpanded(expanded) {
        // Search deliberately opens matching sections. Clear it so a requested
        // collapse takes effect rather than leaving the page visually expanded.
        search.text=""
        Qt.callLater(function(){
            SettingsStore.setSettingsSections(Focus.sectionIds(window.activePage()),expanded)
            scroller.contentY=0
        })
    }
    function capturePreview(path) {content.grabToImage(function(image){image.saveToFile(path)})}
    function frameGeometry() {return {x:content.x,y:content.y,width:content.width,height:content.height,resizeInset:0,resizeBand:7,ready:placementReady}}
    function uiGeometry() {
        function box(item){const point=item.mapToItem(content.parent,0,0);return {x:point.x,y:point.y,width:item.width,height:item.height}}
        const sections=[],sliders=[]
        function visit(item) {
            if(!item || !item.visible)return
            if(typeof item.sectionId === "string")sections.push({id:item.sectionId,expanded:item.expanded,effectiveExpanded:item.effectiveExpanded,box:box(item)})
            if(typeof item.setFromX === "function" && typeof item.valueName === "string")sliders.push({name:item.valueName,value:item.value,adjusting:item.adjusting,box:box(item)})
            const children=item.children || []
            for(let i=0;i<children.length;i++)visit(children[i])
        }
        visit(pageLoader.item)
        return {sections:sections,sliders:sliders,scroll:{box:box(scroller),position:scroller.contentY},pageWidth:pageLoader.width,search:box(searchFrame)}
    }

    function rememberSize() {
        if (!WindowService.maximized) SettingsStore.setSettingsWindowSize(Math.round(width),Math.round(height))
    }
    function requestClose() {
        rememberSize()
        closing=true
        WindowService.request("remember")
    }
    function beginResize(edges) {
        resizeRequests++
        // Hyprland forces the Qt maximized flag even for normal floating windows.
        // Clear only the client hint before requesting the native Wayland gesture.
        if (window.maximized) window.maximized=false
        lastResizeAccepted=window.startSystemResize(edges)
    }
    function performAction(action) {
        if (action === "color-picker" && window.activePage() && window.activePage().openSurfaceColorPicker) window.activePage().openSurfaceColorPicker()
        else if (action === "clear-search") search.text=""
        else if (action === "close") requestClose()
        else if (action === "minimize") WindowService.request("minimize")
        else if (action === "maximize") {
            rememberSize()
            WindowService.request("maximize")
        } else if (action === "restore") WindowService.request("activate")
    }
    function componentForCategory() {
        const pages={appearance:appearanceComponent,bar:barComponent,spotlight:spotlightComponent,weather:weatherComponent,wallpaper:wallpaperComponent,
            displays:displaysComponent,workspaces:workspacesComponent,shortcuts:shortcutsComponent,defaultApps:defaultAppsComponent,
            audio:audioComponent,network:networkComponent,bluetooth:networkComponent,
            power:powerComponent,notifications:notificationsComponent}
        return pages[SettingsStore.settingsWindowCategory] || appearanceComponent
    }
    function iconFor(id) {
        return ({appearance:"◐",bar:"≡",spotlight:"⌕",weather:"☁",wallpaper:"▧",displays:"▣",workspaces:"▦",shortcuts:"⌘",defaultApps:"▧",
            audio:"♫",network:"⌁",bluetooth:"ᛒ",power:"⏻",notifications:"□"})[id] || "·"
    }
    Component.onCompleted: {
        initialWidth=WindowService.geometry.width || 1000
        initialHeight=WindowService.geometry.height || 700
        WindowService.active=visible
        SettingsModel.nativeWindow=window
        history=Settings.initialHistory(window.currentAppearance())
        if (visible) { search.forceActiveFocus();mapTimer.start() }
    }
    onClosed: requestClose()
    onWidthChanged: sizeTimer.restart()
    onHeightChanged: sizeTimer.restart()
    function revealPendingControl() {
        const page=activePage()
        if(!placementReady || !SettingsModel.pendingControl || !page || pageStatus!==Loader.Ready)return
        search.text=""
        page.highlightId=SettingsModel.pendingControl
        SettingsModel.pendingControl=""
        const item=Focus.findControl(page,page.highlightId)
        Focus.revealAncestors(item)
        if(page.focusHighlight)Qt.callLater(page.focusHighlight)
    }
    onPageStatusChanged:Qt.callLater(revealPendingControl)
    Component.onDestruction: { WindowService.active=false;SettingsModel.nativeWindow=null;WindowService.request("cleanup") }
    Timer { id:mapTimer; interval:150; repeat:false; onTriggered:{ window.mapAttempts++;WindowService.request("mapped") } }
    Timer { id:sizeTimer; interval:350; repeat:false; onTriggered:if(window.visible && !WindowService.maximized) { window.rememberSize();WindowService.request("remember") } }
    Connections {
        target: WindowService
        function onCompleted(action,success) {
            if (action === "remember" && window.closing) SettingsModel.hide()
            if (action === "mapped" && success) { window.placementReady=true;search.forceActiveFocus();Qt.callLater(window.revealPendingControl) }
            if (action === "mapped" && !success && window.mapAttempts < 4) mapTimer.restart()
        }
    }
    Connections {
        target: SettingsModel
        function onAppearanceEditRequested(key,value) { const patch={};patch[key]=value;window.commit(patch) }
        function onWindowActionRequested(action) { window.performAction(action) }
        function onFocusTicketChanged() { search.forceActiveFocus();Qt.callLater(window.revealPendingControl) }
        function onPendingControlChanged(){Qt.callLater(window.revealPendingControl)}
    }
    Loader {
        anchors.fill: content
        source: "SettingsShadow.qml"
        active: !WindowService.maximized
        visible: Theme.shadowOpacity > 0 && window.placementReady
        onStatusChanged: {
            if(status === Loader.Ready) SettingsModel.shadowAvailable=true
            else if(status === Loader.Error) SettingsModel.shadowAvailable=false
        }
    }
    Loader {
        active: window.placementReady && WindowService.blurAvailable && SettingsStore.panelBlur > 0
        sourceComponent: Component { BlurAdapter { targetWindow:window;surface:content } }
    }
    Rectangle {
        id: content
        opacity:window.placementReady ? 1 : 0
        anchors.fill: parent
        anchors.margins: window.shadowInset
        radius: WindowService.maximized ? 0 : Theme.radius
        color: Theme.settingsSurface
        focus: true
        Keys.onEscapePressed: function(event) {
            if (search.text !== "") search.text=""
            else window.requestClose()
            event.accepted=true
        }
        Keys.onPressed: function(event) {
            if (!(event.modifiers & Qt.AltModifier) || SettingsStore.settingsWindowCategory!=="appearance") return
            if (event.key === Qt.Key_U) window.undo()
            else if (event.key === Qt.Key_R) window.resetAppearance()
            else return
            event.accepted=true
        }
        Item {
            id: titlebar
            anchors.top:parent.top
            width:parent.width
            height:52
            MouseArea {
                anchors.left:parent.left;anchors.right:windowControls.left
                height:parent.height
                onPressed:window.startSystemMove()
                onDoubleClicked:window.performAction("maximize")
            }
            Text {
                anchors.left:parent.left;anchors.leftMargin:22
                anchors.verticalCenter:parent.verticalCenter
                text:"Settings";color:Theme.settingsText
                font.family:Theme.settingsFontFamily;font.pixelSize:14;font.weight:Font.DemiBold
            }
            Row {
                id:windowControls
                anchors.right:parent.right;anchors.rightMargin:12;anchors.verticalCenter:parent.verticalCenter
                spacing:4
                FlatButton { width:32;label:"−";objectName:"minimizeButton";enabled:WindowService.available;Accessible.name:"Minimize Settings";onActivated:window.performAction("minimize") }
                FlatButton { width:32;label:WindowService.maximized ? "❐" : "□";objectName:"maximizeButton";enabled:WindowService.available;Accessible.name:WindowService.maximized ? "Restore Settings" : "Maximize Settings";onActivated:window.performAction("maximize") }
                FlatButton { width:32;label:"×";objectName:"closeButton";Accessible.name:"Close Settings";onActivated:window.performAction("close") }
            }
        }
        Item {
            id:side
            anchors.top:titlebar.bottom;anchors.left:parent.left;anchors.bottom:parent.bottom
            width:content.width<770 ? 64 : 184
            Rectangle {
                anchors.fill:parent;anchors.margins:10
                radius:Math.min(Theme.radius,10)
                color:Qt.rgba(.5,.5,.5,.035)
            }
            Flickable {
                anchors.fill:parent;anchors.margins:14
                contentHeight:navigationColumn.implicitHeight
                clip:true;boundsBehavior:Flickable.StopAtBounds
                Column {
                    id:navigationColumn
                    width:parent.width
                    spacing:4
                    Repeater {
                        model:Nav.categories()
                        delegate:FlatButton {
                            required property var modelData
                            objectName:modelData.id+"Navigation"
                            navigation:true
                            width:navigationColumn.width;height:38
                            label:side.width<100 ? window.iconFor(modelData.id) : window.iconFor(modelData.id)+"   "+modelData.label
                            Accessible.name:modelData.label
                            emphasized:SettingsStore.settingsWindowCategory===modelData.id
                            onActivated:{search.text="";SettingsStore.setSettingsCategory(modelData.id);scroller.contentY=0}
                        }
                    }
                }
            }
        }
        Item {
            id:body
            anchors.left:side.right;anchors.right:parent.right
            anchors.top:titlebar.bottom;anchors.bottom:parent.bottom
            anchors.rightMargin:14
            Rectangle {
                id:searchFrame
                x:20;y:4;width:Math.max(120,parent.width-40);height:34
                radius:6;color:Theme.settingsHover
                Text {
                    anchors.left:parent.left;anchors.leftMargin:12;anchors.verticalCenter:parent.verticalCenter
                    visible:search.text==="";text:"Search settings";color:Theme.settingsMuted
                    font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                }
                TextInput {
                    id:search
                    objectName:"settingsSearch"
                    anchors.fill:parent;anchors.leftMargin:12;anchors.rightMargin:12
                    verticalAlignment:TextInput.AlignVCenter
                    color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                    selectByMouse:true;activeFocusOnTab:true;clip:true
                    Accessible.name:"Search settings"
                    onTextChanged: {
                        const category=Nav.categoryFor(Nav.firstControlId(text))
                        if (text.trim()!=="" && category!=="") SettingsStore.setSettingsCategory(category)
                        scroller.contentY=0
                    }
                    Keys.onPressed:function(event) {
                        if (!window.activePage()) return
                        const alt=(event.modifiers & Qt.AltModifier)!==0
                        if (alt && (event.key===Qt.Key_J || event.key===Qt.Key_K)) {window.activePage().moveHighlight(event.key===Qt.Key_J ? 1 : -1);event.accepted=true}
                        if (event.key===Qt.Key_Return || event.key===Qt.Key_Enter) {window.activePage().focusHighlight();event.accepted=true}
                    }
                }
            }
            Flow {
                id:pageActions
                x:20;y:searchFrame.y+searchFrame.height+8
                width:Math.max(120,parent.width-40)
                spacing:6
                FlatButton {objectName:"collapseAllSections";label:"Collapse all";onActivated:window.setAllSectionsExpanded(false)}
                FlatButton {objectName:"expandAllSections";label:"Expand all";onActivated:window.setAllSectionsExpanded(true)}
                FlatButton {visible:SettingsStore.settingsWindowCategory==="appearance";label:"Undo appearance";enabled:window.canUndo;onActivated:window.undo()}
                FlatButton {visible:SettingsStore.settingsWindowCategory==="appearance";label:"Reset appearance…";onActivated:window.resetAppearance()}
            }
            Flickable {
                id:scroller
                objectName:"settingsScroller"
                anchors.left:parent.left;anchors.right:parent.right;anchors.top:pageActions.bottom;anchors.topMargin:14
                anchors.bottom:transaction.visible ? transaction.top : (windowNotice.visible ? windowNotice.top : parent.bottom);anchors.bottomMargin:16
                clip:true;boundsBehavior:Flickable.StopAtBounds
                contentWidth:width
                contentHeight:pageLoader.height+16
                Controls.ScrollBar.vertical: Controls.ScrollBar { policy:Controls.ScrollBar.AsNeeded }
                Loader {
                    id:pageLoader
                    onLoaded:scroller.contentY=0
                    x:Math.max(20,(scroller.width-width)/2)
                    width:Math.min(1240,scroller.width-40)
                    height:item ? item.implicitHeight : 0
                    sourceComponent:window.componentForCategory()
                }
            }
            Connections {
                target:pageLoader.item
                ignoreUnknownSignals:true
                function onRevealRequested(y,itemHeight) {scroller.contentY=Nav.scrollTarget(scroller.contentY,scroller.height,y,itemHeight)}
            }
            Text {
                id:windowNotice
                anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
                anchors.margins:12
                text:WindowService.error || WindowService.reasonUnavailable
                visible:text !== ""
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
                wrapMode:Text.WordWrap
            }
            Rectangle {
                id:transaction
                anchors.left:parent.left;anchors.right:parent.right;anchors.bottom:parent.bottom
                height:86;radius:8;color:Theme.settingsSelected
                visible:DisplayService.pending
                Text { x:14;y:10;text:"Keep display changes? " + DisplayService.remaining + " seconds";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize }
                Row {
                    x:12;y:42;spacing:8
                    FlatButton {label:"Keep";emphasized:true;enabled:!DisplayService.busy;onActivated:DisplayService.keep()}
                    FlatButton {label:"Revert";enabled:!DisplayService.busy;onActivated:DisplayService.revert()}
                }
            }
        }
    }
    Controls.Popup {
        id:resetConfirm
        parent:ControlTypes.Overlay.overlay
        x:parent ? Math.round((parent.width-width)/2) : 0
        y:parent ? Math.round((parent.height-height)/2) : 0
        width:Math.min(420,parent ? parent.width-32 : 420)
        padding:18;modal:true;dim:false;focus:true
        closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        background:Rectangle {radius:Theme.radius;color:Theme.settingsPopupSurface}
        contentItem:Column {
            spacing:12
            Text {width:parent.width;text:"Reset appearance?";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+3;font.weight:Font.Medium}
            Text {width:parent.width;text:"Restore SwiftShell’s default colors, surfaces, text and motion. Your wallpaper and display layout stay as they are.";wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            Row {spacing:8;FlatButton {label:"Cancel";onActivated:resetConfirm.close()} FlatButton {label:"Reset appearance";emphasized:true;onActivated:window.confirmResetAppearance()}}
        }
    }
    // Native Wayland resize gestures, including all four corners.
    Repeater {
        model:[Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.LeftEdge|Qt.TopEdge,Qt.RightEdge|Qt.TopEdge,Qt.LeftEdge|Qt.BottomEdge,Qt.RightEdge|Qt.BottomEdge]
        delegate:MouseArea {
            required property int modelData
            readonly property bool corner:(modelData&(Qt.LeftEdge|Qt.RightEdge)) && (modelData&(Qt.TopEdge|Qt.BottomEdge))
            width:corner ? 16 : ((modelData&(Qt.LeftEdge|Qt.RightEdge)) ? 7 : content.width-32)
            height:corner ? 16 : ((modelData&(Qt.TopEdge|Qt.BottomEdge)) ? 7 : content.height-32)
            x:content.x+((modelData&Qt.RightEdge) ? content.width-width : ((modelData&Qt.LeftEdge) ? 0 : 16))
            y:content.y+((modelData&Qt.BottomEdge) ? content.height-height : ((modelData&Qt.TopEdge) ? 0 : 16))
            enabled:!WindowService.maximized
            cursorShape:corner ? (((modelData&Qt.LeftEdge)&&(modelData&Qt.TopEdge)) || ((modelData&Qt.RightEdge)&&(modelData&Qt.BottomEdge)) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : ((modelData&(Qt.LeftEdge|Qt.RightEdge)) ? Qt.SizeHorCursor : Qt.SizeVerCursor)
            onPressed:window.beginResize(modelData)
        }
    }
    Component { id:appearanceComponent;AppearancePage {query:search.text;onEdited:function(patch){window.commit(patch)};onEditStarted:window.beginAppearanceGesture();onEditFinished:window.endAppearanceGesture()} }
    Component {id:weatherComponent;WeatherPage {query:search.text}}
    Component { id:spotlightComponent;SpotlightPage {query:search.text} }
    Component { id:barComponent;BarPage {query:search.text} }
    Component { id:wallpaperComponent;WallpaperPage {query:search.text;onEdited:function(patch){window.commit(patch)}} }
    Component { id:displaysComponent;DisplaysPage {query:search.text} }
    Component { id:workspacesComponent;WorkspacesPage {objectName:"workspacesPage";query:search.text} }
    Component { id:defaultAppsComponent;DefaultAppsPage {query:search.text} }
    Component { id:shortcutsComponent;ShortcutsPage {query:search.text} }
    Component { id:audioComponent;AudioPage {query:search.text} }
    Component { id:networkComponent;NetworkPage {query:search.text} }
    Component { id:bluetoothComponent;BluetoothPage {query:search.text} }
    Component { id:powerComponent;PowerPage {query:search.text} }
    Component { id:notificationsComponent;NotificationsPage {query:search.text} }
}
