import QtQuick
import Quickshell
import "../components"
import "../services"
import "../themes"
Column {
    id:panel
    objectName:"screenshotPanel"
    width:440
    spacing:Theme.settingsSpacing
    Row {
        width:parent.width
        Text {width:parent.width-close.width;height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:"Screenshot";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+5;font.weight:Font.Medium}
        FlatButton {id:close;objectName:"screenshotClose";label:"Close";onActivated:ScreenshotService.close()}
    }
    Text {width:parent.width;text:"Capture an area or a connected display, then copy or save a PNG.";wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    Row {
        spacing:6
        FlatButton {objectName:"screenshotArea";label:"Select area";emphasized:ScreenshotService.mode==="region";enabled:ScreenshotService.regionAvailable && !ScreenshotService.busy;onActivated:ScreenshotService.mode="region"}
        FlatButton {objectName:"screenshotDisplay";label:"Display";emphasized:ScreenshotService.mode==="output";enabled:ScreenshotService.available && !ScreenshotService.busy;onActivated:ScreenshotService.mode="output"}
    }
    ChoiceBox {
        objectName:"screenshotOutput"
        width:parent.width
        visible:ScreenshotService.mode==="output"
        choices:HyprlandModel.monitorChoices.map(function(monitor){return {label:monitor.label,value:monitor.name}})
        selectedValue:ScreenshotService.output
        enabled:!ScreenshotService.busy
        onChosen:function(value){ScreenshotService.output=value}
    }
    Row {
        width:parent.width;spacing:6
        Text {width:58;height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:"Delay";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        Repeater {
            model:[0,3,5]
            FlatButton {required property int modelData;label:modelData===0 ? "None" : modelData+" sec";emphasized:ScreenshotService.delaySeconds===modelData;enabled:!ScreenshotService.busy;onActivated:ScreenshotService.delaySeconds=modelData}
        }
        FlatButton {objectName:"screenshotCapture";label:ScreenshotService.busy ? "Capturing…" : "Capture";emphasized:true;enabled:ScreenshotService.available && !ScreenshotService.busy;onActivated:ScreenshotService.capture(ScreenshotService.mode,ScreenshotService.output)}
    }
    FlatButton {objectName:"screenshotCancel";visible:ScreenshotService.capturing;label:ScreenshotService.countdown>0 ? "Cancel · "+ScreenshotService.countdown+" sec" : "Cancel capture";onActivated:ScreenshotService.cancel()}
    Rectangle {
        width:parent.width;height:ScreenshotService.hasImage ? 220 : 100
        radius:Theme.controlRadius;color:Theme.settingsHover
        Image {objectName:"screenshotPreview";anchors.fill:parent;anchors.margins:8;source:ScreenshotService.imageUrl;sourceSize:Qt.size(1000,600);fillMode:Image.PreserveAspectFit;cache:false;asynchronous:true}
        Text {anchors.centerIn:parent;visible:!ScreenshotService.hasImage;text:"Your screenshot will appear here";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
    }
    Row {
        visible:ScreenshotService.hasImage;width:parent.width;spacing:6
        Text {width:parent.width-copy.width-save.width-discard.width-18;height:Theme.controlHeight;verticalAlignment:Text.AlignVCenter;text:ScreenshotService.imageWidth+" × "+ScreenshotService.imageHeight;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
        FlatButton {id:discard;objectName:"screenshotDiscard";label:"Discard";enabled:!ScreenshotService.busy;onActivated:ScreenshotService.discard()}
        FlatButton {id:copy;objectName:"screenshotCopy";label:"Copy PNG";enabled:!ScreenshotService.busy && ScreenshotService.copyAvailable;onActivated:ScreenshotService.copy()}
        FlatButton {id:save;objectName:"screenshotSave";label:"Save as…";emphasized:true;enabled:!ScreenshotService.busy;onActivated:ScreenshotService.saveAs()}
    }
    Text {width:parent.width;visible:text!=="";text:ScreenshotService.message;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
}
