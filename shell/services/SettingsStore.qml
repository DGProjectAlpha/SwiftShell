pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import "../logic/bar.js" as Bar
import "../logic/workspaces.js" as Workspaces
import "../logic/settings.js" as Settings

Singleton {
    id: root

    readonly property string settingsPath: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/swiftshell/settings.json"
    readonly property int version: adapter.version
    readonly property bool clockSeconds: clockSettings.showSeconds
    readonly property bool clockDate: clockSettings.showDate
    readonly property string clockDateFormat: clockSettings.dateFormat
    readonly property bool searchLabel: barSettings.searchLabel
    readonly property string moduleSidesJson: barSettings.moduleSidesJson
    readonly property string hiddenOutputsJson: barSettings.hiddenOutputsJson
    readonly property bool use24Hour: clockSettings.use24Hour
    readonly property bool showWeekNumbers: clockSettings.showWeekNumbers
    readonly property string weekStart: clockSettings.weekStart
    readonly property string targetMonitor: barSettings.targetMonitor
    readonly property bool reserveSpace: barSettings.reserveSpace
    readonly property bool showFocusedTitle: barSettings.showFocusedTitle
    readonly property string workspaceOutputsJson: barSettings.workspaceOutputsJson
    readonly property var workspaceIds: Settings.normalizeWorkspaceIds(barSettings.workspaceIds)
    readonly property string workspaceDispatch: barSettings.workspaceDispatch === "lua" || barSettings.workspaceDispatch === "legacy" ? barSettings.workspaceDispatch : "auto"
    readonly property string barPlacement: barSettings.placement === "all" || barSettings.placement === "primary" ? barSettings.placement : "focused"
    readonly property int barHeight: barSettings.height
    readonly property var moduleOrder: Bar.normalizeModuleOrder(barSettings.moduleOrder)
    readonly property var hiddenModules: barSettings.hiddenModules
    readonly property var visibleModules: Bar.visibleModules(barSettings.moduleOrder, barSettings.hiddenModules)
    readonly property string barSurfaceMode: barSettings.surfaceMode
    readonly property string barSurfaceColor: barSettings.surfaceColor
    readonly property real barSurfaceOpacity: barSettings.surfaceOpacity
    readonly property string barSurfaceOutputsJson: barSettings.surfaceOutputsJson
    readonly property string appearanceMode: appearanceSettings.mode
    readonly property string appearanceTint: appearanceSettings.tint
    readonly property real panelOpacity: appearanceSettings.panelOpacity
    readonly property real panelBlur: appearanceSettings.panelBlur
    readonly property int radius: appearanceSettings.radius
    readonly property real shadowOpacity: appearanceSettings.shadowOpacity
    readonly property int shadowSoftness: appearanceSettings.shadowSoftness
    readonly property real motionScale: appearanceSettings.motionScale
    readonly property bool reducedMotion: appearanceSettings.reducedMotion
    readonly property int panelPadding: appearanceSettings.panelPadding
    readonly property int panelSpacing: appearanceSettings.panelSpacing
    readonly property int fontSize: appearanceSettings.fontSize
    readonly property string fontWeight: appearanceSettings.fontWeight
    readonly property real iconScale: appearanceSettings.iconScale
    readonly property bool topGradient: appearanceSettings.topGradient
    readonly property string textContrast: appearanceSettings.contrast === "high" ? "high" : "standard"
    readonly property var pinnedIds: Settings.normalizePinnedIds(launcherSettings.pinnedIds)
    readonly property int settingsWindowWidth: windowSettings.width
    readonly property int settingsWindowHeight: windowSettings.height
    readonly property string settingsWindowCategory: windowSettings.category
    readonly property bool wallpaperEnabled: wallpaperSettings.enabled
    readonly property string wallpaperFit: wallpaperSettings.fit === "contain" ? "contain" : "cover"
    readonly property string wallpaperPath: wallpaperSettings.path
    readonly property string wallpaperOutputsJson: wallpaperSettings.outputsJson
    readonly property bool slideshow: wallpaperSettings.slideshow
    readonly property int intervalMinutes: wallpaperSettings.intervalMinutes
    readonly property string slideshowOrder: wallpaperSettings.order === "shuffle" ? "shuffle" : "sequential"
    readonly property int transitionMs: wallpaperSettings.transitionMs
    readonly property string slidesJson: wallpaperSettings.slidesJson
    readonly property bool automaticText: appearanceSettings.automaticText
    readonly property bool automaticGradient: appearanceSettings.automaticGradient
    readonly property string manualText: appearanceSettings.manualText
    readonly property string manualMuted: appearanceSettings.manualMuted
    readonly property string manualPanel: appearanceSettings.manualPanel
    readonly property string manualGradient: appearanceSettings.manualGradient
    readonly property string shortcutsJson: adapter.shortcutsJson
    readonly property string notificationOwnership: notificationSettings.ownership === "on" ? "on" : "off"
    readonly property bool notificationDnd: notificationSettings.dnd === true
    readonly property string notificationPoliciesJson: notificationSettings.policiesJson

    property bool writing: false
    property bool suppressReload: false
    property bool acceptWrites: false
    property bool protectFile: false
    property bool writePending: false
    property string persistedDocument: ""
    property string inflightDocument: ""
    property bool suppressAdapterWrite: false
    property string persistenceState: "loading"
    property string persistenceMessage: ""
    property var pendingPlan: null
    property string pendingRaw: ""
    property bool backupWriting: false

    function writeLatest() {
        if (!root.acceptWrites || root.protectFile || root.pendingPlan)
            return
        var document = JSON.stringify(root.snapshot())
        if (root.writing) {
            root.writePending = document !== root.inflightDocument
            return
        }
        root.writePending = false
        // FileView can skip identical content without emitting saved.
        // Do not enter an in-flight state unless the document actually changed.
        if (document === root.persistedDocument) {
            root.persistenceState = "ready"
            root.persistenceMessage = ""
            return
        }
        root.inflightDocument = document
        root.writing = true
        root.suppressReload = true
        root.persistenceState = "saving"
        settingsFile.writeAdapter()
    }

    function applyDocument(settings) {
        var document = settings || {}
        var clock = document.clock || {}
        var bar = document.bar || {}
        var appearance = document.appearance || {}
        var launcher = document.launcher || {}
        var wallpaper = document.wallpaper || {}
        var window = document.settingsWindow || {}
        var notes = document.notifications || {}
        adapter.version = document.version
        clockSettings.use24Hour = clock.use24Hour === true
        clockSettings.showSeconds = clock.showSeconds === true
        clockSettings.showDate = clock.showDate === true
        clockSettings.dateFormat = clock.dateFormat || "short"
        clockSettings.showWeekNumbers = clock.showWeekNumbers === true
        clockSettings.weekStart = clock.weekStart || "locale"
        barSettings.targetMonitor = bar.targetMonitor || ""
        barSettings.reserveSpace = bar.reserveSpace !== false
        barSettings.showFocusedTitle = bar.showFocusedTitle !== false
        barSettings.workspaceIds = bar.workspaceIds || []
        barSettings.workspaceOutputsJson = bar.workspaceOutputsJson || "{}"
        barSettings.workspaceDispatch = bar.workspaceDispatch || "auto"
        barSettings.placement = bar.placement === "all" || bar.placement === "primary" ? bar.placement : "focused"
        barSettings.height = bar.height
        barSettings.moduleOrder = bar.moduleOrder || []
        barSettings.hiddenModules = bar.hiddenModules || []
        barSettings.surfaceMode = bar.surfaceMode || "transparent"
        barSettings.searchLabel = bar.searchLabel === true
        barSettings.moduleSidesJson = bar.moduleSidesJson || "{}"
        barSettings.hiddenOutputsJson = bar.hiddenOutputsJson || "{}"
        barSettings.surfaceColor = bar.surfaceColor || "#161616"
        barSettings.surfaceOpacity = bar.surfaceOpacity === undefined ? .75 : bar.surfaceOpacity
        barSettings.surfaceOutputsJson = bar.surfaceOutputsJson || "{}"
        appearanceSettings.mode = appearance.mode || "dark"
        appearanceSettings.tint = appearance.tint || "neutral"
        appearanceSettings.panelOpacity = appearance.panelOpacity
        appearanceSettings.panelBlur = appearance.panelBlur
        appearanceSettings.radius = appearance.radius
        appearanceSettings.shadowOpacity = appearance.shadowOpacity
        appearanceSettings.shadowSoftness = appearance.shadowSoftness
        appearanceSettings.motionScale = appearance.motionScale
        appearanceSettings.reducedMotion = appearance.reducedMotion === true
        appearanceSettings.panelPadding = appearance.panelPadding
        appearanceSettings.panelSpacing = appearance.panelSpacing
        appearanceSettings.fontSize = appearance.fontSize
        appearanceSettings.fontWeight = appearance.fontWeight || "regular"
        appearanceSettings.iconScale = appearance.iconScale
        appearanceSettings.topGradient = appearance.topGradient === true
        appearanceSettings.contrast = appearance.contrast === "high" ? "high" : "standard"
        appearanceSettings.automaticText = appearance.automaticText === true
        appearanceSettings.automaticGradient = appearance.automaticGradient === true
        appearanceSettings.manualText = appearance.manualText || ""
        appearanceSettings.manualMuted = appearance.manualMuted || ""
        appearanceSettings.manualPanel = appearance.manualPanel || ""
        appearanceSettings.manualGradient = appearance.manualGradient || ""
        launcherSettings.pinnedIds = launcher.pinnedIds || []
        wallpaperSettings.enabled = wallpaper.enabled !== false
        wallpaperSettings.fit = wallpaper.fit || "cover"
        wallpaperSettings.path = wallpaper.path || ""
        wallpaperSettings.outputsJson = wallpaper.outputsJson || "{}"
        wallpaperSettings.slideshow = wallpaper.slideshow === true
        wallpaperSettings.intervalMinutes = wallpaper.intervalMinutes
        wallpaperSettings.order = wallpaper.order || "sequential"
        wallpaperSettings.transitionMs = wallpaper.transitionMs
        wallpaperSettings.slidesJson = wallpaper.slidesJson || "[]"
        windowSettings.width = window.width
        windowSettings.height = window.height
        windowSettings.category = window.category || "appearance"
        adapter.shortcutsJson = document.shortcutsJson || "{}"
        notificationSettings.ownership = notes.ownership === "on" ? "on" : "off"
        notificationSettings.dnd = notes.dnd === true
        notificationSettings.policiesJson = notes.policiesJson || "{}"
        adapter.extensionsJson = document.extensionsJson || "{}"
    }

    function finishMigration(backupSaved) {
        var plan = root.pendingPlan
        var saved = backupSaved === true
        root.pendingPlan = null
        root.pendingRaw = ""
        if (!Settings.commitMigration(plan, saved)) {
            root.persistenceState = "error"
            root.persistenceMessage = "Settings were left unchanged because the original file could not be backed up."
            console.warn("SwiftShell: settings were not migrated because the backup was not written")
            return
        }
        root.writing = false
        root.inflightDocument = ""
        root.persistedDocument = ""
        root.writePending = false
        root.acceptWrites = true
        root.suppressReload = true
        root.persistenceMessage = ""
        root.suppressAdapterWrite = true
        root.applyDocument(plan.decision.settings)
        root.suppressAdapterWrite = false
        Qt.callLater(root.writeLatest)
    }

    function beginMigration(raw) {
        root.pendingRaw = raw
        root.pendingPlan = Settings.migrationPlan(raw, "")
        backupFile.reload()
    }

    function snapshot() {
        return {
            version: adapter.version,
            clock: {
                use24Hour: clockSettings.use24Hour,
                showSeconds: clockSettings.showSeconds,
                showDate: clockSettings.showDate,
                dateFormat: clockSettings.dateFormat,
                showWeekNumbers: clockSettings.showWeekNumbers,
                weekStart: clockSettings.weekStart
            },
            bar: {
                targetMonitor: barSettings.targetMonitor,
                reserveSpace: barSettings.reserveSpace,
                showFocusedTitle: barSettings.showFocusedTitle,
                workspaceIds: barSettings.workspaceIds,
                workspaceOutputsJson: barSettings.workspaceOutputsJson,
                workspaceDispatch: barSettings.workspaceDispatch,
                placement: barSettings.placement,
                height: barSettings.height,
                moduleOrder: barSettings.moduleOrder,
                surfaceMode: barSettings.surfaceMode,
                surfaceColor: barSettings.surfaceColor,
                surfaceOpacity: barSettings.surfaceOpacity,
                surfaceOutputsJson: barSettings.surfaceOutputsJson,
                searchLabel: barSettings.searchLabel,
                moduleSidesJson: barSettings.moduleSidesJson,
                hiddenOutputsJson: barSettings.hiddenOutputsJson,
                hiddenModules: barSettings.hiddenModules
            },
            appearance: {
                mode: appearanceSettings.mode,
                tint: appearanceSettings.tint,
                panelOpacity: appearanceSettings.panelOpacity,
                panelBlur: appearanceSettings.panelBlur,
                radius: appearanceSettings.radius,
                shadowOpacity: appearanceSettings.shadowOpacity,
                shadowSoftness: appearanceSettings.shadowSoftness,
                motionScale: appearanceSettings.motionScale,
                reducedMotion: appearanceSettings.reducedMotion,
                panelPadding: appearanceSettings.panelPadding,
                panelSpacing: appearanceSettings.panelSpacing,
                fontSize: appearanceSettings.fontSize,
                fontWeight: appearanceSettings.fontWeight,
                iconScale: appearanceSettings.iconScale,
                topGradient: appearanceSettings.topGradient,
                contrast: appearanceSettings.contrast,
                automaticText: appearanceSettings.automaticText,
                automaticGradient: appearanceSettings.automaticGradient,
                manualText: appearanceSettings.manualText,
                manualMuted: appearanceSettings.manualMuted,
                manualPanel: appearanceSettings.manualPanel,
                manualGradient: appearanceSettings.manualGradient
            },
            launcher: {
                pinnedIds: launcherSettings.pinnedIds
            },
            wallpaper: {
                enabled: wallpaperSettings.enabled,
                fit: wallpaperSettings.fit,
                path: wallpaperSettings.path,
                outputsJson: wallpaperSettings.outputsJson,
                slideshow: wallpaperSettings.slideshow,
                intervalMinutes: wallpaperSettings.intervalMinutes,
                order: wallpaperSettings.order,
                transitionMs: wallpaperSettings.transitionMs,
                slidesJson: wallpaperSettings.slidesJson
            },
            settingsWindow: {
                width: windowSettings.width,
                height: windowSettings.height,
                category: windowSettings.category
            },
            shortcutsJson: adapter.shortcutsJson,
            notifications: {
                ownership: notificationSettings.ownership,
                dnd: notificationSettings.dnd,
                policiesJson: notificationSettings.policiesJson
            },
            extensionsJson: adapter.extensionsJson
        };
    }

    function setShortcut(id, modifiers, key) {
        var map = {}
        try {
            map = JSON.parse(adapter.shortcutsJson || "{}")
        } catch (error) {
            map = {}
        }
        if (!map || typeof map !== "object" || Array.isArray(map))
            map = {}
        map[id] = { modifiers: modifiers, key: key }
        adapter.shortcutsJson = Settings.validateSettings({ shortcutsJson: JSON.stringify(map) }).settings.shortcutsJson
    }

    function clearShortcut(id) {
        var map = {}
        try {
            map = JSON.parse(adapter.shortcutsJson || "{}")
        } catch (error) {
            map = {}
        }
        if (!map || typeof map !== "object" || Array.isArray(map))
            map = {}
        delete map[id]
        adapter.shortcutsJson = Settings.validateSettings({ shortcutsJson: JSON.stringify(map) }).settings.shortcutsJson
    }

    function setPanelOpacity(value) {
        const next = Settings.opacityFromUnit(Settings.unitFromOpacity(value))
        appearanceSettings.panelOpacity = next
    }

    function setRadius(value) {
        appearanceSettings.radius = Settings.radiusFromUnit(Settings.unitFromRadius(value))
    }

    function setSettingsWindowSize(width, height) {
        const decision = Settings.validateSettings({
            settingsWindow: { width: width, height: height, category: windowSettings.category }
        })
        windowSettings.width = decision.settings.settingsWindow.width
        windowSettings.height = decision.settings.settingsWindow.height
    }

    function setAppearance(next) {
        const appearance = Settings.validateSettings({ appearance: next }).settings.appearance
        appearanceSettings.mode = appearance.mode
        appearanceSettings.tint = appearance.tint
        appearanceSettings.panelOpacity = appearance.panelOpacity
        appearanceSettings.panelBlur = appearance.panelBlur
        appearanceSettings.radius = appearance.radius
        appearanceSettings.shadowOpacity = appearance.shadowOpacity
        appearanceSettings.shadowSoftness = appearance.shadowSoftness
        appearanceSettings.motionScale = appearance.motionScale
        appearanceSettings.reducedMotion = appearance.reducedMotion
        appearanceSettings.panelPadding = appearance.panelPadding
        appearanceSettings.panelSpacing = appearance.panelSpacing
        appearanceSettings.fontSize = appearance.fontSize
        appearanceSettings.fontWeight = appearance.fontWeight
        appearanceSettings.iconScale = appearance.iconScale
        appearanceSettings.topGradient = appearance.topGradient
        appearanceSettings.contrast = appearance.contrast
        appearanceSettings.automaticText = appearance.automaticText
        appearanceSettings.automaticGradient = appearance.automaticGradient
        appearanceSettings.manualText = appearance.manualText
        appearanceSettings.manualMuted = appearance.manualMuted
        appearanceSettings.manualPanel = appearance.manualPanel
        appearanceSettings.manualGradient = appearance.manualGradient
    }

    function setAppearanceMode(mode) {
        appearanceSettings.mode = mode === "light" ? "light" : "dark"
    }

    function setReducedMotion(value) {
        appearanceSettings.reducedMotion = value === true
    }

    function setTopGradient(value) {
        appearanceSettings.topGradient = value === true
    }

    function setShowWeekNumbers(value) {
        clockSettings.showWeekNumbers = value === true
    }

    function currentBar() {
        return {
            targetMonitor: barSettings.targetMonitor,
            reserveSpace: barSettings.reserveSpace,
            showFocusedTitle: barSettings.showFocusedTitle,
            workspaceIds: barSettings.workspaceIds,
            workspaceOutputsJson: barSettings.workspaceOutputsJson,
            workspaceDispatch: barSettings.workspaceDispatch,
            height: barSettings.height,
            moduleOrder: barSettings.moduleOrder,
            surfaceMode: barSettings.surfaceMode,
            surfaceColor: barSettings.surfaceColor,
            surfaceOpacity: barSettings.surfaceOpacity,
            surfaceOutputsJson: barSettings.surfaceOutputsJson,
            searchLabel: barSettings.searchLabel,
            moduleSidesJson: barSettings.moduleSidesJson,
            hiddenOutputsJson: barSettings.hiddenOutputsJson,
            hiddenModules: barSettings.hiddenModules
        }
    }

    function setClockOptions(seconds, date, format) {
        const next=snapshot().clock
        next.showSeconds=seconds;next.showDate=date;next.dateFormat=format
        const result=Settings.validateSettings({clock:next})
        if(!result.ok) return false
        clockSettings.showSeconds=result.settings.clock.showSeconds
        clockSettings.showDate=result.settings.clock.showDate
        clockSettings.dateFormat=result.settings.clock.dateFormat
        return true
    }
    function setSearchLabel(value) { barSettings.searchLabel=value === true }
    function setModuleSide(id,side) {
        const next=currentBar(),sides=JSON.parse(moduleSidesJson)
        if(Bar.BAR_MODULES.indexOf(id)<0) return false
        sides[id]=side;next.moduleSidesJson=JSON.stringify(sides)
        const result=Settings.validateSettings({bar:next})
        if(!result.ok) return false
        barSettings.moduleSidesJson=result.settings.bar.moduleSidesJson
        return true
    }
    function inheritModuleSide(id) {
        const sides=JSON.parse(moduleSidesJson)
        delete sides[id]
        barSettings.moduleSidesJson=JSON.stringify(sides)
    }
    function resetModuleSides() { barSettings.moduleSidesJson="{}" }
    function hiddenForOutput(output) { return Bar.hiddenForOutput(hiddenModules,hiddenOutputsJson,output) }
    function setHiddenForOutput(output,hidden) {
        if(!Array.isArray(hidden) || !Bar.hiddenModulesValid(hidden)) return false
        if(output === "") { setHiddenModules(hidden);return true }
        const next=currentBar(),outputs=JSON.parse(hiddenOutputsJson)
        if(["__proto__","constructor","prototype"].indexOf(output)>=0) return false
        outputs[output]=hidden;next.hiddenOutputsJson=JSON.stringify(outputs)
        const result=Settings.validateSettings({bar:next})
        if(!result.ok) return false
        barSettings.hiddenOutputsJson=result.settings.bar.hiddenOutputsJson
        return true
    }
    function inheritHidden(output) {
        const outputs=JSON.parse(hiddenOutputsJson)
        delete outputs[output]
        barSettings.hiddenOutputsJson=JSON.stringify(outputs)
    }

    function setUse24Hour(value) {
        clockSettings.use24Hour = value === true
    }

    function setWorkspaceOutput(monitor, keys) {
        const outputs = Workspaces.parseOverrides(root.workspaceOutputsJson) || {}
        outputs[monitor] = keys
        const next = JSON.stringify(outputs)
        const normalized = Workspaces.parseOverrides(next)
        if (normalized === null) return false
        barSettings.workspaceOutputsJson = JSON.stringify(normalized)
        return true
    }

    function setBarPlacement(value) {
        barSettings.targetMonitor = ""
        barSettings.placement = value === "all" || value === "primary" ? value : "focused"
    }

    function setTargetMonitor(value) {
        barSettings.targetMonitor = typeof value === "string" ? value.trim() : ""
    }

    function setReserveSpace(value) {
        barSettings.reserveSpace = value === true
    }

    function setShowFocusedTitle(value) {
        barSettings.showFocusedTitle = value === true
    }

    function setBarSurface(output, mode, color, opacity) {
        if (typeof output !== "string" || output.length>256 || /[\x00-\x1f]/.test(output) || ["__proto__","prototype","constructor"].indexOf(output)>=0) return false
        var next = currentBar()
        if (output === "") {
            next.surfaceMode=mode;next.surfaceColor=color;next.surfaceOpacity=opacity
        } else {
            var overrides = JSON.parse(root.barSurfaceOutputsJson)
            overrides[output]={mode:mode,color:color,opacity:opacity}
            next.surfaceOutputsJson=JSON.stringify(overrides)
        }
        var result=Settings.validateSettings({bar:next})
        if (!result.ok) return false
        root.suppressAdapterWrite=true
        barSettings.surfaceMode=result.settings.bar.surfaceMode
        barSettings.surfaceColor=result.settings.bar.surfaceColor
        barSettings.surfaceOpacity=result.settings.bar.surfaceOpacity
        barSettings.surfaceOutputsJson=result.settings.bar.surfaceOutputsJson
        root.suppressAdapterWrite=false
        Qt.callLater(root.writeLatest)
        return true
    }

    function clearBarSurface(output) {
        var overrides=JSON.parse(root.barSurfaceOutputsJson)
        delete overrides[output]
        barSettings.surfaceOutputsJson=JSON.stringify(overrides)
    }

    function setBarHeight(value) {
        const next = currentBar()
        next.height = value
        barSettings.height = Settings.validateSettings({ bar: next }).settings.bar.height
    }

    function setModuleOrder(order) {
        const next = currentBar()
        next.moduleOrder = order
        barSettings.moduleOrder = Settings.validateSettings({ bar: next }).settings.bar.moduleOrder
    }

    function setHiddenModules(hidden) {
        const next = currentBar()
        next.hiddenModules = hidden
        barSettings.hiddenModules = Settings.validateSettings({ bar: next }).settings.bar.hiddenModules
    }

    function currentWallpaper() {
        return {
            enabled: wallpaperSettings.enabled,
            fit: wallpaperSettings.fit,
            path: wallpaperSettings.path,
            outputsJson: wallpaperSettings.outputsJson,
            slideshow: wallpaperSettings.slideshow,
            intervalMinutes: wallpaperSettings.intervalMinutes,
            order: wallpaperSettings.order,
            transitionMs: wallpaperSettings.transitionMs,
            slidesJson: wallpaperSettings.slidesJson
        }
    }

    function writeWallpaper(next) {
        const decision = Settings.validateSettings({ wallpaper: next }).settings.wallpaper
        wallpaperSettings.enabled = decision.enabled
        wallpaperSettings.fit = decision.fit
        wallpaperSettings.path = decision.path
        wallpaperSettings.outputsJson = decision.outputsJson
        wallpaperSettings.slideshow = decision.slideshow
        wallpaperSettings.intervalMinutes = decision.intervalMinutes
        wallpaperSettings.order = decision.order
        wallpaperSettings.transitionMs = decision.transitionMs
        wallpaperSettings.slidesJson = decision.slidesJson
    }

    function setSlideshow(value) {
        const next = currentWallpaper()
        next.slideshow = value === true
        writeWallpaper(next)
    }

    function setSlideshowOrder(order) {
        const next = currentWallpaper()
        next.order = order
        writeWallpaper(next)
    }

    function setIntervalMinutes(minutes) {
        const next = currentWallpaper()
        next.intervalMinutes = minutes
        writeWallpaper(next)
    }

    function setTransitionMs(ms) {
        const next = currentWallpaper()
        next.transitionMs = ms
        writeWallpaper(next)
    }

    function setSlidesJson(text) {
        const next = currentWallpaper()
        next.slidesJson = text
        writeWallpaper(next)
    }

    function addSlide(path) {
        let list = []
        try {
            list = JSON.parse(wallpaperSettings.slidesJson || "[]")
        } catch (error) {
            list = []
        }
        if (!Array.isArray(list))
            list = []
        list.push(path)
        setSlidesJson(JSON.stringify(list))
    }

    function removeSlide(path) {
        let list = []
        try {
            list = JSON.parse(wallpaperSettings.slidesJson || "[]")
        } catch (error) {
            list = []
        }
        if (!Array.isArray(list))
            list = []
        const kept = []
        for (let index = 0; index < list.length; index++) {
            if (list[index] !== path)
                kept.push(list[index])
        }
        setSlidesJson(JSON.stringify(kept))
    }

    function setWallpaperEnabled(value) {
        const next = currentWallpaper()
        next.enabled = value === true
        writeWallpaper(next)
    }

    function setWallpaperPath(path) {
        const next = currentWallpaper()
        next.path = path
        writeWallpaper(next)
    }

    function setWallpaperFit(fit) {
        const next = currentWallpaper()
        next.fit = fit
        writeWallpaper(next)
    }

    function setWallpaperOutputs(text) {
        const next = currentWallpaper()
        next.outputsJson = text
        writeWallpaper(next)
    }

    function setOutputWallpaper(name, path) {
        let map = {}
        try {
            map = JSON.parse(wallpaperSettings.outputsJson || "{}")
        } catch (error) {
            map = {}
        }
        if (!map || typeof map !== "object")
            map = {}
        if (path === "")
            delete map[name]
        else
            map[name] = path
        setWallpaperOutputs(JSON.stringify(map))
    }

    function setNotificationOwnership(value) {
        notificationSettings.ownership = value === "on" ? "on" : "off"
    }

    function setNotificationDnd(value) {
        notificationSettings.dnd = value === true
    }

    function setNotificationPolicy(id, value) {
        var map = {}
        try {
            map = JSON.parse(notificationSettings.policiesJson || "{}")
        } catch (error) {
            map = {}
        }
        if (!map || typeof map !== "object")
            map = {}
        if (value === "")
            delete map[id]
        else
            map[id] = value
        notificationSettings.policiesJson = Settings.validateSettings({
            notifications: { policiesJson: JSON.stringify(map) }
        }).settings.notifications.policiesJson
    }

    function setSettingsCategory(category) {
        const decision = Settings.validateSettings({
            settingsWindow: {
                width: windowSettings.width,
                height: windowSettings.height,
                category: category
            }
        })
        windowSettings.category = decision.settings.settingsWindow.category
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        atomicWrites: true
        onFileChanged: {
            if (root.suppressReload) {
                root.suppressReload = false;
                return;
            }
            if (!root.writing)
                reload();
        }
        onAdapterUpdated: {
            if (!root.acceptWrites || root.protectFile || root.pendingPlan || root.suppressAdapterWrite)
                return;
            // JsonAdapter updates its serialized cache after this signal.
            // Coalesce edits and write only after those notifications complete.
            Qt.callLater(root.writeLatest);
        }
        onSaved: {
            root.persistedDocument = root.inflightDocument;
            root.inflightDocument = "";
            root.writing = false;
            root.persistenceState = "ready";
            root.persistenceMessage = "";
            if (!root.protectFile) {
                root.acceptWrites = true;
                if (root.writePending)
                    Qt.callLater(root.writeLatest);
            }
        }
        onSaveFailed: function (error) {
            root.inflightDocument = "";
            root.writePending = false;
            root.writing = false;
            root.persistenceState = "error";
            root.persistenceMessage = "Settings could not be saved. Your latest changes are still active for this session.";
            console.warn("SwiftShell: settings were not saved", error);
        }
        onLoaded: {
            root.acceptWrites = false;
            root.protectFile = false;
            root.persistenceState = "loading";
            root.persistenceMessage = "";
            var raw = "";
            try {
                raw = settingsFile.text();
            } catch (error) {
                raw = "";
            }
            var decision = Settings.migrationFromText(raw);
            if (decision.reason === "malformed") {
                root.protectFile = true;
                root.persistenceState = "protected";
                root.persistenceMessage = "Settings contain malformed JSON and were left unchanged. Restore the backup or replace the file before saving.";
                console.warn("SwiftShell: settings file is not valid JSON and was left unchanged");
                return;
            }
            if (decision.reason === "unsupported-version") {
                root.protectFile = true;
                root.persistenceState = "protected";
                root.persistenceMessage = "Settings use a newer unsupported schema and were left unchanged.";
                console.warn("SwiftShell: settings use an unsupported schema version and were left unchanged");
                return;
            }
            if (decision.action === "migrate" || decision.action === "repair") {
                root.beginMigration(raw);
                return;
            }
            if (decision.settings)
                root.applyDocument(decision.settings);
            if (decision.errors && decision.errors.length > 0)
                console.warn("SwiftShell: settings need attention:", decision.errors.join(", "));
            else
                console.info("SwiftShell: settings loaded");
            root.persistedDocument = JSON.stringify(root.snapshot());
            root.inflightDocument = "";
            root.writePending = false;
            root.persistenceState = "ready";
            root.acceptWrites = true;
        }
        onLoadFailed: function (error) {
            console.warn("SwiftShell: settings file is missing or unreadable; using built-in defaults", error);
            root.persistenceState = "ready";
            root.persistenceMessage = "Using built-in defaults. The settings file will be created when a value changes.";
            root.acceptWrites = true;
        }

        JsonAdapter {
            id: adapter
            property int version: 3

            property JsonObject clock: JsonObject {
                id: clockSettings
                property bool use24Hour: true
                property bool showSeconds: false
                property bool showDate: false
                property string dateFormat: "short"
                property bool showWeekNumbers: false
                property string weekStart: "locale"
            }

            property JsonObject bar: JsonObject {
                id: barSettings
                property string targetMonitor: ""
                property bool reserveSpace: true
                property bool showFocusedTitle: true
                property list<int> workspaceIds: []
                property string workspaceOutputsJson: "{}"
                property string workspaceDispatch: "auto"
                property string placement: "focused"
                property int height: 28
                property list<string> moduleOrder: ["workspaces", "title", "search", "clock", "control", "media", "tray", "battery"]
                property list<string> hiddenModules: []
                property bool searchLabel: false
                property string moduleSidesJson: "{}"
                property string hiddenOutputsJson: "{}"
                property string surfaceMode: "transparent"
                property string surfaceColor: "#161616"
                property real surfaceOpacity: .75
                property string surfaceOutputsJson: "{}"
            }

            property JsonObject appearance: JsonObject {
                id: appearanceSettings
                property string mode: "dark"
                property string tint: "neutral"
                property real panelOpacity: 0.92
                property real panelBlur: 1
                property int radius: 10
                property real shadowOpacity: 0.16
                property int shadowSoftness: 10
                property real motionScale: 1
                property bool reducedMotion: false
                property int panelPadding: 12
                property int panelSpacing: 8
                property int fontSize: 13
                property string fontWeight: "regular"
                property real iconScale: 1
                property bool topGradient: false
                property string contrast: "standard"
                property bool automaticText: false
                property bool automaticGradient: false
                property string manualText: ""
                property string manualMuted: ""
                property string manualPanel: ""
                property string manualGradient: ""
            }

            property JsonObject launcher: JsonObject {
                id: launcherSettings
                property list<string> pinnedIds: []
            }

            property JsonObject wallpaper: JsonObject {
                id: wallpaperSettings
                property bool enabled: true
                property string fit: "cover"
                property string path: ""
                property string outputsJson: "{}"
                property bool slideshow: false
                property int intervalMinutes: 30
                property string order: "sequential"
                property int transitionMs: 400
                property string slidesJson: "[]"
            }

            property JsonObject settingsWindow: JsonObject {
                id: windowSettings
                property int width: 1000
                property int height: 700
                property string category: "appearance"
            }

            property string shortcutsJson: "{}"

            property JsonObject notifications: JsonObject {
                id: notificationSettings
                property string ownership: "off"
                property bool dnd: false
                property string policiesJson: "{}"
            }

            property string extensionsJson: "{}"
        }
    }

    FileView {
        id: backupFile
        path: Settings.backupPath(root.settingsPath)
        atomicWrites: true

        function existingText() {
            try {
                return backupFile.text();
            } catch (error) {
                return "";
            }
        }

        function considerBackup() {
            if (root.pendingRaw === "" || root.backupWriting)
                return;
            var plan = Settings.migrationPlan(root.pendingRaw, existingText());
            root.pendingPlan = plan;
            if (!plan.writeSettings) {
                root.pendingPlan = null;
                root.pendingRaw = "";
                root.acceptWrites = true;
                return;
            }
            if (plan.writeBackup) {
                root.backupWriting = true;
                backupFile.setText(root.pendingRaw);
            } else
                root.finishMigration(true);
        }

        // FileView completes its operation after emitting the load signal.
        // Starting a write inside that callback can drop the new operation.
        onLoaded: Qt.callLater(backupFile.considerBackup)
        onLoadFailed: Qt.callLater(backupFile.considerBackup)
        onSaved: {
            root.backupWriting = false;
            if (root.pendingPlan && root.pendingPlan.writeBackup)
                root.finishMigration(true);
        }
        onSaveFailed: function (error) {
            root.backupWriting = false;
            if (root.pendingPlan)
                root.finishMigration(false);
        }
    }
}
