pragma Singleton

import QtQuick
import Quickshell
import "../logic/palette.js" as Palette
import "../logic/theme.js" as ThemeLogic
import "../services"

Singleton {
    readonly property int barHeight: 28
    readonly property int marginH: 10
    readonly property int moduleSpacing: 12
    readonly property int workspaceGap: 2
    readonly property int panelGap: 6
    readonly property int panelMargin: 8
    readonly property int controlHeight: 28
    readonly property int controlRadius: 4
    readonly property int calendarCell: 28
    readonly property int weekNumberWidth: 22
    readonly property int controlWidth: 248

    readonly property var palette: Palette.resolvePalette(SettingsStore.appearanceMode, SettingsStore.appearanceTint)
    readonly property var motion: ThemeLogic.motionDurations(SettingsStore.reducedMotion, SettingsStore.motionScale)

    readonly property int fontSize: SettingsStore.fontSize
    readonly property int fontSizeSmall: Math.max(11, fontSize - 1)
    readonly property int fontWeight: SettingsStore.fontWeight === "medium" ? Font.Medium : Font.Normal
    readonly property string fontFamily: ""
    readonly property color textPrimary: palette.appearance === "light" ? "#1A1A1A" : "#F2F2F2"
    readonly property color textMuted: palette.appearance === "light" ? "#525252" : "#A3A3A3"
    readonly property color textHover: palette.appearance === "light" ? "#2E2E2E" : "#D4D4D4"
    readonly property color transparent: Qt.rgba(0, 0, 0, 0)
    readonly property color panelText: Qt.rgba(palette.text.r / 255, palette.text.g / 255, palette.text.b / 255, 1)
    readonly property color panelMuted: Qt.rgba(palette.muted.r / 255, palette.muted.g / 255, palette.muted.b / 255, 1)
    readonly property color panelHover: Qt.rgba(palette.hover.r / 255, palette.hover.g / 255, palette.hover.b / 255, 1)
    readonly property color panelColor: Qt.rgba(palette.panel.r / 255, palette.panel.g / 255, palette.panel.b / 255, SettingsStore.panelOpacity)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 1)
    readonly property color gradientTop: palette.appearance === "light" ? Qt.rgba(255, 255, 255, 0.55) : Qt.rgba(0, 0, 0, 0.34)

    readonly property real panelOpacity: SettingsStore.panelOpacity
    readonly property real panelBlur: SettingsStore.panelBlur
    readonly property int radius: SettingsStore.radius
    readonly property real shadowOpacity: SettingsStore.shadowOpacity
    readonly property int shadowSoftness: SettingsStore.shadowSoftness
    readonly property int panelPadding: SettingsStore.panelPadding
    readonly property int panelSpacing: SettingsStore.panelSpacing
    readonly property real iconScale: SettingsStore.iconScale
    readonly property bool topGradient: SettingsStore.topGradient
    readonly property bool reducedMotion: SettingsStore.reducedMotion
    readonly property string adaptiveReason: palette.adaptiveReason
    readonly property int motionOpen: motion.open
    readonly property int motionClose: motion.close
    readonly property int motionHover: motion.hover
    readonly property int calendarWidth: calendarCell * 7 + (SettingsStore.showWeekNumbers ? weekNumberWidth : 0)
}
