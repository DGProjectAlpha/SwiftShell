import QtQuick
import "../components"
import "../logic/bar.js" as Bar
import "../services"
import "../themes"
Item {
    id:menu
    required property string outputName
    readonly property string displayLabel: {
        const choice=HyprlandModel.monitorChoices.find(function(m){return m.name===menu.outputName})
        return choice ? choice.label : outputName
    }
    signal customizeRequested()
    implicitWidth:240
    implicitHeight:column.implicitHeight
    function geometry() {
        const result=[]
        for(let i=0;i<toggles.count;i++) {
            const item=toggles.itemAt(i),position=item.mapToItem(null,0,0)
            result.push({module:item.modelData,x:position.x,y:position.y,width:item.width,height:item.height})
        }
        const customize=customizeButton.mapToItem(null,0,0)
        result.push({module:"customize",x:customize.x,y:customize.y,width:customizeButton.width,height:customizeButton.height})
        return result
    }
    Column {
        id:column
        width:menu.width
        spacing:Theme.settingsSpacing
        Text {text:"Bar modules";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+1;font.weight:Font.Medium}
        Text {width:parent.width;elide:Text.ElideRight;text:menu.displayLabel;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Repeater {
            id:toggles
            model:Bar.BAR_MODULES
            delegate:SettingsToggle {
                required property string modelData
                width:column.width;height:Theme.controlHeight
                label:Bar.moduleName(modelData)
                checked:SettingsStore.hiddenForOutput(menu.outputName).indexOf(modelData)<0
                onToggled:function(value) {
                    SettingsStore.setHiddenForOutput(menu.outputName,Bar.toggleHidden(SettingsStore.hiddenForOutput(menu.outputName),modelData))
                }
            }
        }
        FlatButton {
            visible:Object.prototype.hasOwnProperty.call(JSON.parse(SettingsStore.hiddenOutputsJson),menu.outputName)
            label:"Use all-screen visibility"
            onActivated:SettingsStore.inheritHidden(menu.outputName)
        }
        FlatButton {id:customizeButton;label:"Customize bar…";onActivated:menu.customizeRequested()}
    }
}
