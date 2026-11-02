import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import Quickshell.Wayland
import "../logic/bar.js" as Bar
import "../logic/contrast.js" as Contrast
import "../logic/windows.js" as Windows
import "../logic/workspaces.js" as Workspaces
import "../components"
import "../popovers"
import "../services"
import "../themes"

PanelWindow {
    id: window

    required property var modelData

    screen: modelData
    color: Theme.transparent
    focusable: false
    implicitHeight: Theme.barHeight
    property Item controlAnchor: null
    property Item networkAnchor:null
    property Item powerAnchor:null
    property Item calendarAnchor: null
    property var clockItem: null
    property var trayItem:null
    readonly property var outputHidden:SettingsStore.hiddenForOutput(monitorKey)
    function modulesOn(side) { return Bar.modulesForSide(SettingsStore.moduleOrder,outputHidden,SettingsStore.moduleSidesJson,side) }
    function moduleLayout() { return {left:{x:leftModules.x,width:leftModules.width},center:{x:centerModules.x,width:centerModules.width},right:{x:rightModules.x,width:rightModules.width}} }
    function menuDiagnostics() { return {geometry:popovers.geometry(),blurBounds:popovers.blurBounds,id:popovers.popupState.panelId,visible:popovers.visible,blur:popovers.surfaceBlurApplied,width:popovers.implicitWidth,height:popovers.implicitHeight,x:popovers.placement.x,y:popovers.placement.y} }
    function showPanel(id) {
        if(id === "close") {popovers.close();return}
        if((id === "calendar" || id === "clock" || id === "date") && calendarAnchor) popovers.openClock(id==="date" ? "calendar" : "clock",calendarAnchor)
        else if(id === "control" && controlAnchor) popovers.toggle(id,controlAnchor)
        else if(id === "network" && networkAnchor)popovers.toggle(id,networkAnchor)
        else if(id === "power" && powerAnchor)popovers.toggle(id,powerAnchor)
        else if(id === "customize") {contextAnchor.x=width-100;popovers.toggle(id,contextAnchor)}
    }

    anchors {
        top: true
        left: true
        right: true
    }

    // Top stays under true fullscreen. Overlay would cover fullscreen clients.
    // keyboardFocus None keeps the bar from taking text input.
    WlrLayershell.namespace: "swiftshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool reserveSpace: SettingsStore.reserveSpace
    readonly property string hyprlandMonitorName: HyprlandModel.hyprlandNameForScreen(modelData)
    readonly property string monitorKey: hyprlandMonitorName !== "" ? hyprlandMonitorName : (modelData && modelData.name ? modelData.name : "")
    readonly property string analysisKey: modelData && modelData.name ? modelData.name : monitorKey
    readonly property var outputAnalysis: ColorAnalysis.sampleForOutput(analysisKey)
    readonly property var outputSurface: Theme.surfaceForAnalysis(outputAnalysis)
    readonly property bool useSurfaceForeground: barSurface.visible && barSurface.alpha >= .5
    readonly property bool darkSurfaceForeground: useSurfaceForeground && Contrast.chooseForeground(Contrast.parseHex(barSurface.color), "").foreground === "dark"
    readonly property color outputTextPrimary: useSurfaceForeground && SettingsStore.manualText === "" ? (darkSurfaceForeground ? "#1a1a1a" : "#f2f2f2") : Qt.rgba(outputSurface.text.r / 255, outputSurface.text.g / 255,
                                                       outputSurface.text.b / 255, 1)
    readonly property color outputTextMuted: useSurfaceForeground && SettingsStore.manualMuted === "" ? (darkSurfaceForeground ? "#525252" : "#c4c4c4") : Qt.rgba(outputSurface.muted.r / 255, outputSurface.muted.g / 255,
                                                     outputSurface.muted.b / 255, 1)
    readonly property bool contrastFade:SettingsStore.automaticText && (!outputAnalysis.available || outputAnalysis.scrim) && (!barSurface.visible || barSurface.alpha<.85)
    readonly property color outputGradientTop:contrastFade ? Qt.rgba(0,0,0,.68) : Qt.rgba(outputSurface.gradient.r/255,outputSurface.gradient.g/255,outputSurface.gradient.b/255,outputSurface.gradientAlpha)
    function foregroundFor(id,muted) {
        const manual=muted ? SettingsStore.manualMuted : SettingsStore.manualText
        if(manual && !SettingsStore.automaticText) return manual
        if(!SettingsStore.automaticText) return muted ? outputTextMuted : outputTextPrimary
        const side=Bar.moduleSide(id,SettingsStore.moduleSidesJson,SettingsStore.moduleOrder)
        const base=outputAnalysis.backgrounds ? outputAnalysis.backgrounds[side] : null
        if(barSurface.visible && barSurface.alpha>=.85) {
            const dark=Contrast.chooseForeground(Contrast.parseHex(barSurface.color),"").foreground==="dark"
            return dark ? (muted ? "#333333" : "#111111") : (muted ? "#dedede" : "#ffffff")
        }
        if(contrastFade || !base)return muted ? "#e1e1e1" : "#ffffff"
        const color=Contrast.parseHex(barSurface.color) || {r:0,g:0,b:0}
        const alpha=barSurface.visible ? barSurface.alpha : 0
        const effective={r:base.r*(1-alpha)+color.r*alpha,g:base.g*(1-alpha)+color.g*alpha,b:base.b*(1-alpha)+color.b*alpha}
        const dark=Contrast.chooseForeground(effective,"").foreground==="dark"
        return dark ? (muted ? "#333333" : "#111111") : (muted ? "#dedede" : "#ffffff")
    }
    readonly property var barSurface: Bar.surfaceForOutput(SettingsStore.barSurfaceMode, SettingsStore.barSurfaceColor,
        SettingsStore.barSurfaceOpacity, SettingsStore.barSurfaceOutputsJson, monitorKey, SurfaceService.blurAvailable)
    readonly property bool surfaceBlurApplied: backdrop.applied
    readonly property var workspaceItems: Workspaces.perMonitorItems(SettingsStore.workspaceOutputsJson, SettingsStore.workspaceIds, SettingsStore.targetMonitor, HyprlandModel.liveWorkspaces, monitorKey)
    readonly property int activeWorkspaceId: {
        for (let i = 0; i < workspaceItems.length; i++) {
            if (workspaceItems[i].active)
                return workspaceItems[i].id;
        }
        return -1;
    }
    readonly property string windowTitle: Windows.focusedTitle(HyprlandModel.liveToplevels, monitorKey, activeWorkspaceId)

    function openLauncher() {
        popovers.close();
        LauncherModel.openLauncher();
    }

    function syncExclusion() {
        const update = Bar.exclusionUpdate(reserveSpace, Theme.barHeight, exclusiveZone);
        if (update.mode === "normal") {
            // Writing exclusiveZone forces Normal, but assigning the same height again
            // does not call the setter. The mode write is what turns reservation back on.
            if (update.writeZone)
                exclusiveZone = update.zone;
            exclusionMode = ExclusionMode.Normal;
            console.info("SwiftShell: bar reserves", update.zone, "logical px on", monitorKey);
            return;
        }
        exclusionMode = ExclusionMode.Ignore;
        console.info("SwiftShell: bar reserves no space on", monitorKey, "(overlay)");
    }

    Component.onCompleted: syncExclusion()
    onReserveSpaceChanged: syncExclusion()
    onImplicitHeightChanged: syncExclusion()

    Rectangle {
        id: background
        z: -2
        anchors.fill: parent
        visible: window.barSurface.visible
        color: window.barSurface.color
        opacity: window.barSurface.alpha
        radius: Math.min(Theme.radius,height/2)
    }
    BackdropEffect {
        id: backdrop
        targetWindow: window
        surface: background
        cornerRadius: background.radius
        enabled: window.barSurface.blur
    }

    Rectangle {
        z: -1
        visible: Theme.topGradient || outputSurface.scrim || window.contrastFade
        anchors.fill: parent
        color: Theme.transparent
        gradient: Gradient {
            GradientStop { position: 0.0; color: window.outputGradientTop }
            GradientStop { position: window.contrastFade ? .72 : 0; color: window.outputGradientTop }
            GradientStop { position: 1.0; color: Theme.transparent }
        }
    }

    ModuleStrip {
        id:leftModules
        barWindow:window;modules:window.modulesOn("left")
        x:Theme.marginH
        onWidthChanged:if(popovers)popovers.reposition()
    }
    ModuleStrip {
        id:rightModules
        barWindow:window;modules:window.modulesOn("right")
        x:window.width-Theme.marginH-width
        onXChanged:if(popovers)popovers.reposition()
    }
    ModuleStrip {
        id:centerModules
        barWindow:window;modules:window.modulesOn("center")
        readonly property real freeLeft:leftModules.x+leftModules.width+Theme.moduleSpacing
        readonly property real freeRight:rightModules.x-Theme.moduleSpacing
        titleWidth:Math.min(480,Math.max(0,freeRight-freeLeft-fixedWidth))
        x:Math.max(freeLeft,Math.min((window.width-width)/2,freeRight-width))
        onXChanged:if(popovers)popovers.reposition()
    }
    Item { id:contextAnchor;y:0;width:1;height:Theme.barHeight }
    MouseArea {
        z:-.5
        anchors.fill:parent
        acceptedButtons:Qt.RightButton
        onClicked:function(mouse) {
            LauncherModel.closeLauncher()
            contextAnchor.x=mouse.x
            popovers.toggle("customize",contextAnchor)
        }
    }

    function componentFor(id) {
        if (id === "workspaces")
            return workspacesComponent
        if (id === "title")
            return titleComponent
        if (id === "search")
            return searchComponent
        if (id === "clock")
            return clockComponent
        if (id === "control")
            return controlComponent
        if (id === "network")return networkComponent
        if (id === "power")return powerComponent
        if (id === "media")
            return mediaComponent
        if (id === "tray")
            return trayComponent
        if (id === "battery")
            return batteryComponent
        return null
    }

    Component {
        id: workspacesComponent

        WorkspaceIndicators {
            workspaces: window.workspaceItems
            monitorName: window.monitorKey
            textPrimary: window.foregroundFor("workspaces",false)
            textMuted: window.foregroundFor("workspaces",true)
            textHover: window.foregroundFor("workspaces",false)
        }
    }

    Component {
        id: titleComponent

        Item {
            implicitHeight: Theme.barHeight

            FocusedTitle {
                anchors.fill: parent
                title: SettingsStore.showFocusedTitle ? window.windowTitle : ""
                textMuted: window.foregroundFor("title",true)
            }
        }
    }

    Component {
        id: searchComponent

        MouseArea {
            id: searchButton
            implicitWidth: Math.max(Theme.barHeight,searchContents.implicitWidth)
            implicitHeight: Theme.barHeight
            width: implicitWidth
            height: implicitHeight
            hoverEnabled: true
            activeFocusOnTab: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: "Search"
            Accessible.description: "Open the launcher"

            onClicked: window.openLauncher()

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    window.openLauncher()
                    event.accepted = true
                }
            }

            Controls.ToolTip.visible:containsMouse
            Controls.ToolTip.text:"Search"
            Controls.ToolTip.delay:600
            Row {
                id:searchContents
                anchors.centerIn:parent
                spacing:6
                Item {
                    width:Theme.barIcon;height:Theme.barIcon
                    readonly property color ink:searchButton.containsMouse || searchButton.activeFocus ? window.foregroundFor("search",false) : window.foregroundFor("search",true)
                    Rectangle {width:parent.width*.6;height:width;radius:width/2;anchors.left:parent.left;anchors.top:parent.top;color:"transparent";border.width:1.5;border.color:parent.ink}
                    Rectangle {width:parent.width*.48;height:1.5;rotation:45;x:parent.width*.51;y:parent.height*.73;color:parent.ink}
                }
                BarLabel {
                    visible:SettingsStore.searchLabel
                    text:"Search"
                    color:searchButton.containsMouse || searchButton.activeFocus ? window.foregroundFor("search",false) : window.foregroundFor("search",true)
                }
            }
        }
    }

    Component {
        id: clockComponent

        ClockModule {
            id: clockModule
            Component.onCompleted:{window.calendarAnchor=clockModule;window.clockItem=clockModule}
            Component.onDestruction:{if(window.calendarAnchor===clockModule)window.calendarAnchor=null;if(window.clockItem===clockModule)window.clockItem=null}
            textPrimary: window.foregroundFor("clock",false)
            textHover: window.foregroundFor("clock",false)
            onActivated: {
                LauncherModel.closeLauncher()
                popovers.openClock("clock", clockModule)
            }
            onCalendarActivated: {
                LauncherModel.closeLauncher()
                popovers.openClock("calendar",clockModule)
            }
        }
    }

    Component {
        id: mediaComponent

        Item {
            implicitWidth: mediaLoader.item ? mediaLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: mediaLoader
                source: "MediaModule.qml"
                active: true
                onLoaded: {
                    if (item) {
                        item.textPrimary = window.foregroundFor("media",false)
                        item.textMuted = window.foregroundFor("media",true)
                    }
                }
            }
            Binding {
                target: mediaLoader.item
                property: "textPrimary"
                value: window.foregroundFor("media",false)
                when: mediaLoader.status === Loader.Ready
            }
            Binding {
                target: mediaLoader.item
                property: "textMuted"
                value: window.foregroundFor("media",true)
                when: mediaLoader.status === Loader.Ready
            }
        }
    }

    Component {
        id: trayComponent

        Item {
            implicitWidth: trayLoader.item ? trayLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: trayLoader
                source: "TrayModule.qml"
                active: true
                onLoaded: {
                    if (item) {
                        item.hostWindow = window
                        window.trayItem=item
                        item.textPrimary = window.foregroundFor("tray",false)
                        item.textMuted = window.foregroundFor("tray",true)
                    }
                }
            }
            Binding {
                target: trayLoader.item
                property: "textPrimary"
                value: window.foregroundFor("tray",false)
                when: trayLoader.status === Loader.Ready
            }
            Binding {
                target: trayLoader.item
                property: "textMuted"
                value: window.foregroundFor("tray",true)
                when: trayLoader.status === Loader.Ready
            }
        }
    }

    Component {
        id: batteryComponent

        Item {
            implicitWidth: batteryLoader.item ? batteryLoader.item.implicitWidth : 0
            implicitHeight: Theme.barHeight

            Loader {
                id: batteryLoader
                source: "BatteryModule.qml"
                active: true
                onLoaded: {
                    if (item)
                        item.textPrimary = window.foregroundFor("battery",false)
                }
            }
            Binding {
                target: batteryLoader.item
                property: "textPrimary"
                value: window.foregroundFor("battery",false)
                when: batteryLoader.status === Loader.Ready
            }
        }
    }

    Component {
        id: controlComponent

        ControlIndicator {
            id: controlIndicator
            textPrimary: window.foregroundFor("control",false)
            textMuted: window.foregroundFor("control",true)
            textHover: window.foregroundFor("control",false)
            Component.onCompleted: window.controlAnchor = controlIndicator
            Component.onDestruction: {
                if (window.controlAnchor === controlIndicator)
                    window.controlAnchor = null
            }
            onActivated: {
                LauncherModel.closeLauncher()
                popovers.toggle("control", controlIndicator)
            }
        }
    }

    Component {
        id:networkComponent
        WidgetIndicator {
            id:networkIndicator
            kind:"network";label:"Network & Devices"
            textPrimary:window.foregroundFor("network",false)
            textHover:window.foregroundFor("network",false)
            connected:NetworkService.connectivity==="full" || NetworkService.connectivity==="limited"
            Component.onCompleted:{window.networkAnchor=networkIndicator;NetworkService.startViewing()}
            Component.onDestruction:{NetworkService.stopViewing();if(window.networkAnchor===networkIndicator)window.networkAnchor=null}
            onActivated:{LauncherModel.closeLauncher();popovers.toggle("network",networkIndicator)}
        }
    }
    Component {
        id:powerComponent
        WidgetIndicator {
            id:powerIndicator
            kind:"power";label:"Power"
            textPrimary:window.foregroundFor("power",false)
            textHover:window.foregroundFor("power",false)
            Component.onCompleted:window.powerAnchor=powerIndicator
            Component.onDestruction:if(window.powerAnchor===powerIndicator)window.powerAnchor=null
            onActivated:{LauncherModel.closeLauncher();popovers.toggle("power",powerIndicator)}
        }
    }
    Component {
        id:contextPanel
        BarContextMenu {
            outputName:window.monitorKey
            onCustomizeRequested:{popovers.close();SettingsStore.setSettingsCategory("bar");SettingsModel.show()}
        }
    }

    PopoverHost {
        id: popovers
        barWindow: window
        customPanel:contextPanel
    }

    Connections {
        target: LauncherModel
        function onControlRequested() {
            if(window.monitorKey!==HyprlandModel.readFocusedOutput())return
            if (window.controlAnchor)
                popovers.toggle("control", window.controlAnchor)
        }
    }
}
