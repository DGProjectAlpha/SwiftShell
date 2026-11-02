import QtQuick
import "../services"
import "../themes"
Column {
    id:options
    property bool compact:false
    spacing:4
    function geometry() {
        const result=[]
        for(let i=0;i<profileRows.count;i++) {
            const row=profileRows.itemAt(i),point=row.mapToItem(null,0,0)
            result.push({id:row.modelData.id,x:point.x,y:point.y,width:row.width,height:row.height,enabled:row.modelData.enabled})
        }
        return result
    }
        Repeater {
            id:profileRows
            model:PowerProfiles.available ? PowerProfiles.profiles : []
            delegate:Rectangle {
                id:profile
                required property var modelData
                width:options.width;height:options.compact ? 38 : Math.max(64,profileTexts.implicitHeight+20)
                radius:Math.min(8,Theme.radius)
                color:PowerProfiles.active===modelData.id ? Theme.settingsSelected : (target.containsMouse || target.activeFocus ? Theme.settingsHover : "transparent")
                opacity:modelData.enabled ? 1 : .5
                Text {
                    x:14;anchors.verticalCenter:parent.verticalCenter
                    text:PowerProfiles.active===profile.modelData.id ? "●" : "○"
                    color:Theme.settingsText;font.pixelSize:17
                }
                Column {
                    id:profileTexts
                    x:44;width:parent.width-60;anchors.verticalCenter:parent.verticalCenter;spacing:3
                    Text {width:parent.width;text:profile.modelData.label;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:PowerProfiles.active===profile.modelData.id ? Font.Medium : Font.Normal}
                    Text {width:parent.width;text:profile.modelData.description;visible:!options.compact;wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                }
                MouseArea {
                    id:target
                    objectName:"powerProfile-"+profile.modelData.id
                    anchors.fill:parent;hoverEnabled:true;activeFocusOnTab:true
                    enabled:!PowerProfiles.busy && profile.modelData.enabled
                    cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    Accessible.role:Accessible.RadioButton
                    Accessible.name:profile.modelData.label
                    Accessible.description:profile.modelData.description
                    Accessible.checkable:true
                    Accessible.checked:PowerProfiles.active===profile.modelData.id
                    function activate() {PowerProfiles.choose(profile.modelData.id)}
                    onClicked:activate()
                    Keys.onPressed:function(event) {if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space){activate();event.accepted=true}}
                }
            }
        }
}
