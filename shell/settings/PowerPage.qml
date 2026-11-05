import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"powerProfiles"
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function geometry() {return {active:PowerProfiles.active,profiles:options.geometry(),busy:PowerProfiles.busy}}
    function shows(id) {return Nav.controlVisible(query,id)}
    function focusHighlight() {refreshButton.forceActiveFocus()}
    function moveHighlight(delta) {revealRequested(0,height)}
    Component.onCompleted:{PowerProfiles.viewers++;if(!PowerProfiles.busy)PowerProfiles.refresh()}
    Component.onDestruction:PowerProfiles.viewers=Math.max(0,PowerProfiles.viewers-1)
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {text:"Power";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}

        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Choose how your computer balances speed and energy use.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}

        Row {
            spacing:8
            FlatButton {id:refreshButton;label:PowerProfiles.busy ? "Updating…" : "Refresh";enabled:!PowerProfiles.busy;onActivated:PowerProfiles.refresh()}
            FlatButton {visible:PowerProfiles.canUndo;label:"Undo profile change";enabled:!PowerProfiles.busy;onActivated:PowerProfiles.undo()}
        }

        Text {
            width:parent.width;wrapMode:Text.WordWrap
            visible:PowerProfiles.error!=="" || !PowerProfiles.available
            text:PowerProfiles.error || "Checking available power profiles…"
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }

        SettingsSection {
            sectionId:"power.profiles"
            title:"Power profile"
            description:""
            searchQuery:page.query
            controlIds:["powerProfiles"]
            width:parent.width
            PowerProfileOptions {id:options;width:parent.width}
            Text {
                visible:text!=="";width:parent.width;wrapMode:Text.WordWrap
                text:PowerProfiles.reason(PowerProfiles.inhibited || PowerProfiles.degraded)
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
            Text {
                visible:PowerProfiles.holds>0;width:parent.width;wrapMode:Text.WordWrap
                text:PowerProfiles.holds===1 ? "An application is holding a power profile." : PowerProfiles.holds+" applications are holding power profiles."
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }

        SettingsSection {
            sectionId:"power.battery"
            title:"Battery"
            description:""
            searchQuery:page.query
            controlIds:["battery"]
            width:parent.width
            visible:batteryLoader.status===Loader.Ready && batteryLoader.item && batteryLoader.item.report.available
            Loader {
                id:batteryLoader
                width:parent.width
                active:page.shows("battery")
                source:"../popovers/BatterySection.qml"
                visible:status===Loader.Ready && item && item.report.available
            }
        }
    }
}
