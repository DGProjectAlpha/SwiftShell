//@ pragma ShellId swiftshell-bar-settings-audit
import QtQuick
import Quickshell
import "services" as Services
import "settings" as SettingsUI
import "bar" as Bars
import "logic/settingsFocus.js" as Focus
import "logic/bar.js" as Bar

// Copied into a temporary shell tree. Every native window stays unmapped.
ShellRoot {
    id:audit
    property var first:null
    property var second:null
    property int phase:0
    property var untouched:null
    SettingsUI.BarPage {id:page;visible:false;width:560}
    SettingsUI.SettingsWindow {id:settings;visible:false}
    Component {id:barComponent;Bars.BarWindow {visible:false}}
    function require(condition,message) {if(!condition)throw new Error(message)}
    function find(node,name) {
        if(node.objectName===name)return node
        for(const child of node.children || []) {const result=find(child,name);if(result)return result}
        return null
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            if(Services.SettingsStore.persistenceState!=="ready" || Quickshell.screens.length<2)return
            try {
                if(audit.phase===0) {
                    audit.first=barComponent.createObject(audit,{modelData:Quickshell.screens[0],visible:false})
                    audit.second=barComponent.createObject(audit,{modelData:Quickshell.screens[1],visible:false})
                    audit.require(audit.first!==null && audit.second!==null,"Native BarWindow construction failed")
                    audit.require(audit.first.monitorKey!==audit.second.monitorKey,"Distinct outputs required")
                    audit.phase=1
                    return
                }
                if(audit.phase===1) {
                    if(Quickshell.env("SWIFTSHELL_AUDIT_READBACK")==="1") {
                        audit.require(audit.first.implicitHeight===42 && audit.second.implicitHeight===28,"Native per-output size restart readback")
                        audit.require(!audit.first.reserveSpace && audit.second.reserveSpace,"Native reservation restart readback")
                        audit.require(audit.first.outputLayout.showSeconds && !audit.second.outputLayout.showSeconds,"Clock preferences restart readback")
                        audit.require(Focus.sectionIds(settings.activePage()).every(function(id){return JSON.parse(Services.SettingsStore.settingsSectionsJson)[id]===false}),"Collapsed categories restart readback")
                        console.info("Bar settings audit: native restart readback passed")
                        Qt.quit();return
                    }
                    audit.untouched={height:audit.second.implicitHeight,width:audit.second.implicitWidth,reserve:audit.second.reserveSpace,scale:audit.second.contentScale}
                    page.selectOutput(audit.first.monitorKey)
                    find(page,"barSizeSlider").moved(Bar.unitFromSize(42))
                    find(page,"barReserveSpace").toggled(false)
                    find(page,"barClockSeconds").toggled(true)
                    Services.SettingsStore.setSettingsCategory("bar")
                    settings.setAllSectionsExpanded(false)
                    audit.phase=2;return
                }
                audit.require(audit.first.implicitHeight===42,"Selected native bar did not resize")
                audit.require(!audit.first.reserveSpace,"Selected native reservation did not update")
                audit.require(audit.second.implicitHeight===audit.untouched.height && audit.second.implicitWidth===audit.untouched.width && audit.second.reserveSpace===audit.untouched.reserve && audit.second.contentScale===audit.untouched.scale,"Other native bar changed")
                audit.require(!audit.first.visible && !audit.second.visible && !settings.visible,"Audit window unexpectedly mapped")
                audit.require(Focus.sectionIds(settings.activePage()).every(function(id){return JSON.parse(Services.SettingsStore.settingsSectionsJson)[id]===false}),"Collapse all did not persist")
                console.info("Bar settings audit: native size isolation and save passed")
                Qt.quit()
            } catch(error) {console.warn("Bar settings audit FAILED: "+error);Qt.quit()}
        }
    }
    Timer {interval:10000;running:true;onTriggered:{console.warn("Bar settings audit FAILED: timed out (two outputs required)");Qt.quit()}}
}
