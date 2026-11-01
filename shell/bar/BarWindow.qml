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
    property Item calendarAnchor: null
    property var clockItem: null
    readonly property var outputHidden:SettingsStore.hiddenForOutput(monitorKey)
    function modulesOn(side) { return Bar.modulesForSide(SettingsStore.moduleOrder,outputHidden,SettingsStore.moduleSidesJson,side) }
    function moduleLayout() { return {left:{x:leftModules.x,width:leftModules.width},center:{x:centerModules.x,width:centerModules.width},right:{x:rightModules.x,width:rightModules.width}} }
    function menuDiagnostics() { return {geometry:popovers.geometry(),blurBounds:popovers.blurBounds,id:popovers.popupState.panelId,visible:popovers.visible,blur:popovers.surfaceBlurApplied,width:popovers.implicitWidth,height:popovers.implicitHeight,x:popovers.placement.x,y:popovers.placement.y} }
    function showPanel(id) {
        if(id === "close") {popovers.close();return}
        if(id === "calendar" && calendarAnchor) popovers.toggle(id,calendarAnchor)
        else if(id === "control" && controlAnchor) popovers.toggle(id,controlAnchor)
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
    readonly property color outputGradientTop: Qt.rgba(outputSurface.gradient.r / 255,
                                                       outputSurface.gradient.g / 255,
                                                       outputSurface.gradient.b / 255,
                                                       outputSurface.gradientAlpha)
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
        visible: Theme.topGradient || outputSurface.scrim
        anchors.fill: parent
        color: Theme.transparent
        gradient: Gradient {
            GradientStop { position: 0.0; color: window.outputGradientTop }
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
        z:100
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
            textPrimary: window.outputTextPrimary
            textMuted: window.outputTextMuted
            textHover: window.outputTextPrimary
        }
    }

    Component {
        id: titleComponent

        Item {
            implicitHeight: Theme.barHeight

            FocusedTitle {
                anchors.fill: parent
                title: SettingsStore.showFocusedTitle ? window.windowTitle : ""
                textMuted: window.outputTextMuted
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
                    readonly property color ink:searchButton.containsMouse || searchButton.activeFocus ? window.outputTextPrimary : window.outputTextMuted
                    Rectangle {width:parent.width*.6;height:width;radius:width/2;anchors.left:parent.left;anchors.top:parent.top;color:"transparent";border.width:1.5;border.color:parent.ink}
                    Rectangle {width:parent.width*.48;height:1.5;rotation:45;x:parent.width*.51;y:parent.height*.73;color:parent.ink}
                }
                BarLabel {
                    visible:SettingsStore.searchLabel
                    text:"Search"
                    color:searchButton.containsMouse || searchButton.activeFocus ? window.outputTextPrimary : window.outputTextMuted
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
            textPrimary: window.outputTextPrimary
            textHover: window.outputTextPrimary
            onActivated: {
                LauncherModel.closeLauncher()
                popovers.toggle("calendar", clockModule)
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
                        item.textPrimary = window.outputTextPrimary
                        item.textMuted = window.outputTextMuted
                    }
                }
            }
            Binding {
                target: mediaLoader.item
                property: "textPrimary"
                value: window.outputTextPrimary
                when: mediaLoader.status === Loader.Ready
            }
            Binding {
                target: mediaLoader.item
                property: "textMuted"
                value: window.outputTextMuted
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
                        item.textPrimary = window.outputTextPrimary
                        item.textMuted = window.outputTextMuted
                    }
                }
            }
            Binding {
                target: trayLoader.item
                property: "textPrimary"
                value: window.outputTextPrimary
                when: trayLoader.status === Loader.Ready
            }
            Binding {
                target: trayLoader.item
                property: "textMuted"
                value: window.outputTextMuted
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
                        item.textPrimary = window.outputTextPrimary
                }
            }
            Binding {
                target: batteryLoader.item
                property: "textPrimary"
                value: window.outputTextPrimary
                when: batteryLoader.status === Loader.Ready
            }
        }
    }

    Component {
        id: controlComponent

        ControlIndicator {
            id: controlIndicator
            textPrimary: window.outputTextPrimary
            textMuted: window.outputTextMuted
            textHover: window.outputTextPrimary
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
            if (window.controlAnchor)
                popovers.toggle("control", window.controlAnchor)
        }
    }
}
