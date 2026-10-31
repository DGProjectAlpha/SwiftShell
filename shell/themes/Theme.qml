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
    readonly property int panelGap: 6
    readonly property int panelMargin: 8
    readonly property int controlHeight: 28
    readonly property int controlRadius: 4
    readonly property int calendarCell: 28
    readonly property int weekNumberWidth: 22
    readonly property int controlWidth: 248

    readonly property var palette: Palette.resolvePalette(SettingsStore.appearanceMode, SettingsStore.appearanceTint, SettingsStore.textContrast)
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
    readonly property var motion: ThemeLogic.motionDurations(SettingsStore.reducedMotion, SettingsStore.motionScale)

    readonly property int fontSize: SettingsStore.fontSize
    readonly property int fontSizeSmall: Math.max(11, fontSize - 1)
    readonly property int fontWeight: SettingsStore.fontWeight === "medium" ? Font.Medium : Font.Normal
    readonly property string fontFamily: ""
    readonly property color textPrimary: Qt.rgba(surface.text.r / 255, surface.text.g / 255, surface.text.b / 255, 1)
    readonly property color textMuted: Qt.rgba(surface.muted.r / 255, surface.muted.g / 255, surface.muted.b / 255, 1)
    readonly property color transparent: Qt.rgba(0, 0, 0, 0)
    readonly property var panelHoverUnits: Palette.colorUnits(palette.hover, 1)
    readonly property var panelUnits: Palette.colorUnits(surface.panel, SettingsStore.panelOpacity)
    readonly property var gradientUnits: Palette.colorUnits(surface.gradient, surface.gradientAlpha)
    // Foreground follows the surface, so a manual hex and automatic png text reach the bar and the panels.
    readonly property color panelText: textPrimary
    readonly property color panelMuted: textMuted
    readonly property color panelHover: Qt.rgba(panelHoverUnits.r, panelHoverUnits.g, panelHoverUnits.b, panelHoverUnits.a)
    readonly property color textHover: panelHover
    readonly property color panelColor: Qt.rgba(panelUnits.r, panelUnits.g, panelUnits.b, panelUnits.a)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 1)
    readonly property color gradientTop: Qt.rgba(gradientUnits.r, gradientUnits.g, gradientUnits.b, gradientUnits.a)

    readonly property real panelOpacity: SettingsStore.panelOpacity
    // Stored only. Quickshell 0.2 has no BackgroundEffect, so this does not blur the panel.
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
    readonly property string adaptiveReason: palette.adaptiveReason
    readonly property int motionOpen: motion.open
    readonly property int motionClose: motion.close
    readonly property int motionHover: motion.hover
    readonly property int calendarWidth: ThemeLogic.calendarWidth(calendarCell, weekNumberWidth, SettingsStore.showWeekNumbers)
}
