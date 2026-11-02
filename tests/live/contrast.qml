//@ pragma ShellId swiftshell-contrast-audit
import QtQuick
import Quickshell
import "bar" as Bar
import "services" as Services
ShellRoot {
    id:audit
    property int stage:0
    Bar.BarWindow {id:bar;modelData:Quickshell.screens[0];visible:false}
    function source(name) {
        Services.ColorAnalysis.registerOutput(bar.analysisKey,bar.screen.width,bar.screen.height,Quickshell.env(name))
    }
    function fail(message) {console.warn("Contrast audit: FAILED",message);Qt.quit()}
    Timer {
        interval:50;repeat:true;running:true
        onTriggered: {
            if(Services.SettingsStore.persistenceState!=="ready")return
            if(audit.stage===0) {
                const prefs=Services.SettingsStore.snapshot().appearance;prefs.automaticText=true
                Services.SettingsStore.setAppearance(prefs)
                Services.SettingsStore.setBarSurface("","solid","#ffffff",1)
                if(bar.contrastFade || bar.foregroundFor("clock",false)!=="#111111")return audit.fail("Opaque white bar must remain light with dark text even before image analysis")
                Services.SettingsStore.setBarSurface("","transparent","#161616",0)
                audit.source("SWIFTSHELL_WHITE");audit.stage=1
            } else if(audit.stage===1 && bar.outputAnalysis.available && bar.outputAnalysis.backgrounds.center.r>245) {
                if(bar.foregroundFor("clock",false)!=="#111111")return audit.fail("JPEG white wallpaper must choose dark text")
                audit.source("SWIFTSHELL_BLACK");audit.stage=2
            } else if(audit.stage===2 && bar.outputAnalysis.available && bar.outputAnalysis.backgrounds.center.r<8) {
                if(bar.foregroundFor("clock",false)!=="#ffffff")return audit.fail("WebP black wallpaper must choose light text")
                Services.SettingsStore.setBarSurface("","solid","#eeeeee",.95);audit.stage=3
            } else if(audit.stage===3) {
                if(bar.foregroundFor("clock",false)!=="#111111")return audit.fail("Effective light bar material must override wallpaper foreground")
                Services.SettingsStore.setBarSurface("","transparent","#161616",0)
                audit.source("SWIFTSHELL_MIXED");audit.stage=4
            } else if(audit.stage===4 && bar.outputAnalysis.available && bar.outputAnalysis.scrim) {
                if(!bar.contrastFade || bar.foregroundFor("clock",false)!=="#ffffff")return audit.fail("Mixed wallpaper needs a stable readability fade")
                console.info("Contrast audit: JPEG/WebP and composed bar surfaces passed")
                Qt.quit()
            }
        }
    }
    Timer {interval:10000;running:true;onTriggered:audit.fail("timed out")}
}
