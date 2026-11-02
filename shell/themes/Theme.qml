pragma Singleton

import QtQuick
import Quickshell
import "../logic/bar.js" as BarMetrics
import "../logic/contrast.js" as Contrast
import "../logic/palette.js" as Palette
import "../logic/theme.js" as ThemeLogic
import "../services"

Singleton {
    readonly property var barMetrics: BarMetrics.barMetrics(SettingsStore.barHeight, SettingsStore.iconScale)
    readonly property int barHeight: barMetrics.height
    readonly property int barFont: barMetrics.font
    readonly property int barIcon: barMetrics.icon
    readonly property int marginH: barMetrics.marginH
    readonly property int moduleSpacing: barMetrics.moduleSpacing
    readonly property int workspaceGap: barMetrics.workspaceGap
    readonly property int surfaceShadowInset:32
    readonly property int panelGap: 6
    readonly property int panelMargin: 8
    readonly property int controlHeight: 28
    readonly property int controlRadius: 4
    readonly property int calendarCell: 28
    readonly property int weekNumberWidth: 22
    readonly property int controlWidth: 248

    readonly property var themePalette: Palette.resolvePalette(SettingsStore.appearanceMode, SettingsStore.appearanceTint, SettingsStore.textContrast)
    readonly property var surface: Contrast.surfaceColors({
        mode: SettingsStore.appearanceMode,
        contrast: SettingsStore.textContrast,
        automaticText: SettingsStore.automaticText,
        automaticGradient: SettingsStore.automaticGradient,
        manualText: SettingsStore.manualText,
        manualMuted: SettingsStore.manualMuted,
        manualPanel: SettingsStore.manualPanel,
        manualGradient: SettingsStore.manualGradient,
        analysis: ColorAnalysis.sample
    })
    function surfaceForAnalysis(analysis) {
        return Contrast.surfaceColors({
            mode: SettingsStore.appearanceMode,
            contrast: SettingsStore.textContrast,
            automaticText: SettingsStore.automaticText,
            automaticGradient: SettingsStore.automaticGradient,
            manualText: SettingsStore.manualText,
            manualMuted: SettingsStore.manualMuted,
            manualPanel: SettingsStore.manualPanel,
            manualGradient: SettingsStore.manualGradient,
            analysis: analysis
        })
    }
    readonly property var motion: ThemeLogic.motionDurations(SettingsStore.reducedMotion, SettingsStore.motionScale)

    readonly property string settingsFontFamily: "Noto Sans"
    readonly property int settingsFontSize: SettingsStore.fontSize
    readonly property int settingsFontSizeSmall: Math.max(11, settingsFontSize - 1)
    readonly property bool lightSurface:Contrast.chooseForeground(surface.panel, "").foreground === "dark"
    readonly property var floaterPalette:Palette.resolvePalette(lightSurface ? "light" : "dark","neutral",SettingsStore.textContrast)
    readonly property color settingsText: SettingsStore.manualText !== "" ? SettingsStore.manualText : Qt.rgba(floaterPalette.text.r/255,floaterPalette.text.g/255,floaterPalette.text.b/255,1)
    readonly property color settingsMuted: SettingsStore.manualMuted !== "" ? SettingsStore.manualMuted : Qt.rgba(floaterPalette.muted.r/255,floaterPalette.muted.g/255,floaterPalette.muted.b/255,1)
    readonly property color settingsPopupSurface: Qt.rgba(surface.panel.r/255,surface.panel.g/255,surface.panel.b/255,.98)
    readonly property color settingsHover: lightSurface ? Qt.rgba(0,0,0,.05) : Qt.rgba(1,1,1,.07)
    readonly property color settingsSelected: lightSurface ? Qt.rgba(0,0,0,.09) : Qt.rgba(1,1,1,.11)
    readonly property int settingsSpacing: Math.max(6, Math.round(SettingsStore.panelSpacing * .75))
    readonly property color settingsSurface: floaterSurface

    readonly property color floaterSurface: Qt.rgba(surface.panel.r/255,surface.panel.g/255,surface.panel.b/255,
        SurfaceService.blurAvailable && SettingsStore.textContrast !== "high" ? SettingsStore.panelOpacity * .8 : .98)

    readonly property int fontSize: SettingsStore.fontSize
    readonly property int fontSizeSmall: Math.max(11, fontSize - 1)
    readonly property int fontWeight: SettingsStore.fontWeight === "medium" ? Font.Medium : Font.Normal
    readonly property string fontFamily: settingsFontFamily
    readonly property color textPrimary: Qt.rgba(surface.text.r / 255, surface.text.g / 255, surface.text.b / 255, 1)
    readonly property color textMuted: Qt.rgba(surface.muted.r / 255, surface.muted.g / 255, surface.muted.b / 255, 1)
    readonly property color transparent: Qt.rgba(0, 0, 0, 0)
    readonly property var panelHoverUnits: Palette.colorUnits(themePalette.hover, 1)
    readonly property var panelUnits: Palette.colorUnits(surface.panel, SettingsStore.panelOpacity)
    readonly property var gradientUnits: Palette.colorUnits(surface.gradient, surface.gradientAlpha)
    // Foreground follows the surface, so a manual hex and automatic png text reach the bar and the panels.
    readonly property color panelText: settingsText
    readonly property color panelMuted: settingsMuted
    readonly property color panelHover: settingsHover
    readonly property color textHover: panelHover
    readonly property color panelColor: Qt.rgba(panelUnits.r, panelUnits.g, panelUnits.b, panelUnits.a)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 1)
    readonly property color gradientTop: Qt.rgba(gradientUnits.r, gradientUnits.g, gradientUnits.b, gradientUnits.a)

    readonly property real panelOpacity: SettingsStore.panelOpacity
    // Shared native backdrop blur; DesktopAppearance controls compositor strength.
    readonly property real panelBlur: SettingsStore.panelBlur
    readonly property int radius: SettingsStore.radius
    readonly property real shadowOpacity: SettingsStore.shadowOpacity
    readonly property int shadowSoftness: SettingsStore.shadowSoftness
    readonly property int panelPadding: SettingsStore.panelPadding
    readonly property int panelSpacing: SettingsStore.panelSpacing
    readonly property real iconScale: SettingsStore.iconScale
    readonly property bool topGradient: SettingsStore.topGradient
    readonly property bool contrastScrim: surface.scrim
    readonly property string contrastReason: surface.reason
    readonly property string contrastWarning: surface.warning
    readonly property bool reducedMotion: SettingsStore.reducedMotion
    readonly property string adaptiveReason: themePalette.adaptiveReason
    readonly property int motionOpen: motion.open
    readonly property int motionClose: motion.close
    readonly property int motionHover: motion.hover
    readonly property int calendarWidth: ThemeLogic.calendarWidth(calendarCell, weekNumberWidth, SettingsStore.showWeekNumbers)
}
