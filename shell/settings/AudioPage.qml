import QtQuick
import "../components"
import "../logic/settingsNav.js" as Nav
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:""
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function shows(id){return Nav.controlVisible(page.query,id)}
    function focusHighlight() {
        const sections={audioOutput:outputGroup,audioInput:inputGroup,audioStream:appsGroup,mediaPlayer:mediaGroup,trayItems:trayGroup}
        const group=sections[highlightId]
        if(group){group.reveal();revealRequested(group.y,group.height)}
        column.forceActiveFocus()
    }
    function moveHighlight(delta){highlightId=Nav.moveSelection(query,highlightId,delta)}
    Column {
        id:column;width:page.width;spacing:Theme.settingsSpacing+6;activeFocusOnTab:true
        Text {width:parent.width;text:"Audio";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Adjust speakers, microphone and application volume. Control playback from connected players.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        SettingsSection {
            id:outputGroup;sectionId:"audio.output";title:"Output";description:"Choose speakers or headphones and adjust their volume."
            controlIds:["audioOutput"];searchQuery:page.query
            Loader {
                width:parent.width;active:outputGroup.effectiveExpanded && page.shows("audioOutput");source:"../popovers/AudioSection.qml"
                onLoaded:{item.heading="";item.showOutput=true;item.showInput=false;item.showApplications=false}
            }
        }
        SettingsSection {
            id:inputGroup;sectionId:"audio.input";title:"Microphone";description:"Choose an input, set gain, or mute your microphone."
            controlIds:["audioInput"];searchQuery:page.query;defaultExpanded:false
            Loader {
                width:parent.width;active:inputGroup.effectiveExpanded && page.shows("audioInput");source:"../popovers/AudioSection.qml"
                onLoaded:{item.heading="";item.showOutput=false;item.showInput=true;item.showApplications=false}
            }
        }
        SettingsSection {
            id:appsGroup;sectionId:"audio.applications";title:"Applications";description:"Set the volume of apps currently using audio."
            controlIds:["audioStream"];searchQuery:page.query;defaultExpanded:false
            Loader {
                width:parent.width;active:appsGroup.effectiveExpanded && page.shows("audioStream");source:"../popovers/AudioSection.qml"
                onLoaded:{item.heading="";item.showOutput=false;item.showInput=false;item.showApplications=true}
            }
        }
        SettingsSection {
            id:mediaGroup;sectionId:"audio.media";title:"Media playback";description:"Choose a player and control its playback."
            controlIds:["mediaPlayer"];searchQuery:page.query;defaultExpanded:false
            Loader {width:parent.width;active:mediaGroup.effectiveExpanded && page.shows("mediaPlayer");source:"../popovers/MediaSection.qml"}
        }
        SettingsSection {
            id:trayGroup;sectionId:"audio.tray";title:"Tray applications";description:"Background applications and their controls."
            controlIds:["trayItems"];searchQuery:page.query;defaultExpanded:false
            Loader {width:parent.width;active:trayGroup.effectiveExpanded && page.shows("trayItems");source:"../popovers/TraySection.qml";onLoaded:item.hostWindow=Window.window}
        }
    }
}
