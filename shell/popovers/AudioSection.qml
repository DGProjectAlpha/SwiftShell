import QtQuick
import "../components"
import "../services"
import "../logic/audio.js" as Audio
import "../themes"
Column {
    id:root
    property string heading:"Audio"
    property bool showOutput:true
    property bool showInput:true
    property bool showApplications:true
    property string outputGesture:""
    property string inputGesture:""
    readonly property var sink:AudioService.sink
    readonly property var sourceNode:AudioService.source
    readonly property bool ready:AudioService.outputReady
    readonly property bool sourceReady:AudioService.inputReady
    spacing:Theme.settingsSpacing+4
    width:parent ? parent.width : Theme.controlWidth
    function diagnostics(){return AudioService.diagnostics()}
    function applyMute(muted){return AudioService.setMuted(AudioService.idFor("sink"),muted)}
    function percentText(){return volumeSlider.adjusting ? String(Audio.percent(volumeSlider.value)) : ready ? String(Audio.percent(sink.audio.volume)) : ""}
    SectionHeader {width:parent.width;text:root.heading;visible:root.heading!==""}
    Column {
        visible:root.showOutput;width:parent.width;spacing:Theme.settingsSpacing
        Row {
            width:parent.width
            Text {width:parent.width-outputMute.width;height:outputMute.height;verticalAlignment:Text.AlignVCenter;text:"Output";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
            FlatButton {id:outputMute;objectName:"audioOutputMute";label:root.ready && root.sink.audio.muted ? "Unmute" : "Mute";enabled:root.ready;onActivated:root.applyMute(!root.sink.audio.muted)}
        }
        ChoiceBox {
            objectName:"audioOutputDevice";width:parent.width
            choices:AudioService.outputs.map(function(device){return {label:device.label,value:device.id}})
            selectedValue:AudioService.idFor("sink");enabled:AudioService.outputs.length>0
            customLabel:root.sink ? Audio.nodeName(root.sink) : "No output device"
            Accessible.name:"Output device"
            onChosen:function(value){AudioService.chooseDefault(value,"sink")}
        }
        Row {
            width:parent.width;spacing:10
            CompactSlider {
                id:volumeSlider;objectName:"audioOutputVolume";width:Math.max(1,parent.width-outputPercent.width-10);enabled:root.ready;valueName:"Output volume"
                Binding {target:volumeSlider;property:"value";when:!volumeSlider.adjusting;value:root.ready ? root.sink.audio.volume : 0}
                onAdjustingChanged:root.outputGesture=adjusting ? AudioService.idFor("sink") : ""
                onMoved:function(value){AudioService.setDefaultVolume("sink",root.outputGesture,value)}
            }
            Text {id:outputPercent;width:42;height:volumeSlider.height;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:root.ready ? root.percentText()+"%" : "—";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        Text {visible:!root.ready;width:parent.width;wrapMode:Text.WordWrap;text:AudioService.connected ? "Waiting for an output device." : "Audio service is unavailable.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    }
    Column {
        visible:root.showInput;width:parent.width;spacing:Theme.settingsSpacing
        Row {
            width:parent.width
            Text {width:parent.width-inputMute.width;height:inputMute.height;verticalAlignment:Text.AlignVCenter;text:"Microphone";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
            FlatButton {id:inputMute;objectName:"audioInputMute";label:root.sourceReady && root.sourceNode.audio.muted ? "Unmute" : "Mute";enabled:root.sourceReady;onActivated:AudioService.setMuted(AudioService.idFor("source"),!root.sourceNode.audio.muted)}
        }
        ChoiceBox {
            objectName:"audioInputDevice";width:parent.width
            choices:AudioService.inputs.map(function(device){return {label:device.label,value:device.id}})
            selectedValue:AudioService.idFor("source");enabled:AudioService.inputs.length>0
            customLabel:root.sourceNode ? Audio.nodeName(root.sourceNode) : "No input device"
            Accessible.name:"Microphone device"
            onChosen:function(value){AudioService.chooseDefault(value,"source")}
        }
        Row {
            width:parent.width;spacing:10
            CompactSlider {
                id:sourceSlider;objectName:"audioInputVolume";width:Math.max(1,parent.width-inputPercent.width-10);enabled:root.sourceReady;valueName:"Microphone gain"
                Binding {target:sourceSlider;property:"value";when:!sourceSlider.adjusting;value:root.sourceReady ? root.sourceNode.audio.volume : 0}
                onAdjustingChanged:root.inputGesture=adjusting ? AudioService.idFor("source") : ""
                onMoved:function(value){AudioService.setDefaultVolume("source",root.inputGesture,value)}
            }
            Text {id:inputPercent;width:42;height:sourceSlider.height;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:root.sourceReady ? Audio.percent(sourceSlider.adjusting ? sourceSlider.value : root.sourceNode.audio.volume)+"%" : "—";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        Text {visible:!root.sourceReady;width:parent.width;wrapMode:Text.WordWrap;text:"No microphone is available.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    }
    Column {
        visible:root.showApplications;width:parent.width;spacing:Theme.settingsSpacing
        Text {width:parent.width;text:"Applications";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
        Text {visible:AudioService.streams.length===0;width:parent.width;text:"Active applications appear here when they use audio.";wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        KeyedModel {id:streamRows;entries:AudioService.streams}
        Repeater {
            model:streamRows
            delegate:Column {
                id:stream;required property var entry
                readonly property var modelData:entry
                width:parent.width;spacing:2
                Text {width:parent.width;text:stream.modelData.label;textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                CompactSlider {
                    id:streamSlider;objectName:"audioApplicationVolume-"+stream.modelData.id
                    width:parent.width;valueName:stream.modelData.label
                    enabled:AudioService.nodeReady(AudioService.nodeById(stream.modelData.id))
                    Binding {target:streamSlider;property:"value";when:!streamSlider.adjusting;value:stream.modelData.volume===null ? 0 : stream.modelData.volume}
                    onMoved:function(value){AudioService.setVolume(stream.modelData.id,value)}
                }
            }
        }
    }
    Text {visible:AudioService.error!=="";width:parent.width;wrapMode:Text.WordWrap;text:AudioService.error;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
}
