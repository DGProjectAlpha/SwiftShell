//@ pragma ShellId swiftshell-cold-start-audit
import QtQuick
import Quickshell
import "services" as Services
ShellRoot {
    property bool changed:false
    function matches(store) {
        const saved=store.snapshot();
        return saved.appearance.accentColor==="#7296a8" && saved.appearance.opaqueWindows===false
            && saved.bar.fullscreenPeek===true && JSON.parse(saved.settingsWindow.sectionsJson)["appearance.surface"]===false
            && saved.weather.query==="Owned fixture" && saved.weather.units==="imperial"
            && saved.bar.hiddenOutputsJson.indexOf("HDMI-A-1")>=0;
    }
    Timer {
        interval:80;running:true;repeat:true
        onTriggered:{
            const store=Services.SettingsStore;
            if(store.persistenceState!=="ready")return;
            if(Quickshell.env("SWIFTSHELL_COLD_READ")==="1") {
                if(!matches(store)){console.error("Cold settings read FAILED");Qt.quit();return}
                console.info("Cold settings read PASS");Qt.quit();return;
            }
            if(!changed){
                changed=true;
                store.setAppearance({accentColor:"#7296a8",opaqueWindows:false});
                store.setFullscreenBarPeek(true);
                store.setSettingsSection("appearance.surface",false);
                store.setWeatherPreferences({query:"Owned fixture",units:"imperial",refreshMinutes:30});
                store.setHiddenForOutput("HDMI-A-1",["tray","performance"]);
                return;
            }
            if(!matches(store)){console.error("Cold settings write FAILED");Qt.quit();return}
            console.info("Cold settings write PASS");Qt.quit();
        }
    }
    Timer {interval:8000;running:true;onTriggered:{console.error("Cold settings timeout",Services.SettingsStore.persistenceState);Qt.quit()}}
}
