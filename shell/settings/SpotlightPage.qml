import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../services"
import "../themes"

Item {
    id: page
    property string query: ""
    property string highlightId: ""
    signal revealRequested(real y, real itemHeight)
    implicitWidth: 560
    implicitHeight: column.implicitHeight
    height: implicitHeight

    function shows(id) { return Nav.controlVisible(query,id); }
    function moveHighlight(delta) { highlightId=Nav.moveSelection(query,highlightId,delta); }
    function focusHighlight() { if(shows("spotlightDefaultMode"))startMode.forceActiveFocus(); }
    onQueryChanged: highlightId=Nav.firstControlId(query)
    onHighlightIdChanged: if(highlightId==="spotlightDefaultMode")revealRequested(startRow.y,startRow.height)

    Column {
        id: column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {
            width:parent.width
            text:"Spotlight Search"
            color:Theme.settingsText
            font.family:Theme.settingsFontFamily
            font.pixelSize:Theme.settingsFontSize+4
            font.weight:Font.Medium
        }
        Text {
            width:parent.width
            text:"Your apps, settings and quick answers, one shortcut away."
            wrapMode:Text.WordWrap
            color:Theme.settingsMuted
            font.family:Theme.settingsFontFamily
            font.pixelSize:Theme.settingsFontSizeSmall
        }
        Column {
            width:parent.width
            visible:page.shows("spotlightDefaultMode")
            spacing:Theme.settingsSpacing
            SectionHeader { text:"Opening view" }
            SettingsRow {
                id:startRow
                width:parent.width
                controlId:"spotlightDefaultMode"
                label:"Start with"
                marked:page.highlightId===controlId
                ChoiceBox {
                    id:startMode
                    objectName:"spotlightDefaultModeChoice"
                    width:Math.min(240,Math.max(180,page.width-24))
                    choices:[{label:"All apps",value:"all"},{label:"Favorites",value:"favorites"},{label:"Recent apps",value:"recent"}]
                    selectedValue:SettingsStore.launcherDefaultMode
                    Accessible.name:"Spotlight opening view"
                    onChosen:function(value){SettingsStore.setLauncherDefaultMode(value);}
                }
            }
            Text {
                width:parent.width
                text:SettingsStore.launcherDefaultMode==="favorites"
                    ? "Open with your handpicked apps. Right-click an app in All apps, or press Ctrl+D, to add it to Favorites."
                    : SettingsStore.launcherDefaultMode==="recent"
                    ? "Open with apps you recently launched from Spotlight. Your search text is never saved."
                    : "Open with every installed app in a scrolling grid. Switch to Favorites or Recent whenever you like."
                wrapMode:Text.WordWrap
                color:Theme.settingsMuted
                font.family:Theme.settingsFontFamily
                font.pixelSize:Theme.settingsFontSizeSmall
            }
            Text {
                width:parent.width
                text:"This view opens each time you summon Spotlight. Switching tabs while it is open keeps your saved choice."
                wrapMode:Text.WordWrap
                color:Theme.settingsMuted
                font.family:Theme.settingsFontFamily
                font.pixelSize:Theme.settingsFontSizeSmall
            }
            FlatButton {
                objectName:"spotlightOpenButton"
                label:"Open Spotlight"
                onActivated:LauncherModel.openLauncher()
            }
        }
        Text {
            width:parent.width
            visible:!page.shows("spotlightDefaultMode")
            text:"No matching settings"
            color:Theme.settingsMuted
            font.family:Theme.settingsFontFamily
            font.pixelSize:Theme.settingsFontSize
        }
    }
}
