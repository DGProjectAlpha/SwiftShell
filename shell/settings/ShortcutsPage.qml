import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell.Wayland
import "../components"
import "../services"
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"shortcuts"
    property string filter:""
    property string section:"managed"
    property string recordingId:""
    property var draftModifiers:[]
    property string draftKey:""
    property string recordError:""
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function recordingStatus() {return {active:inhibitor.active,id:recordingId,modifiers:draftModifiers,key:draftKey}}
    function focusHighlight() {search.forceActiveFocus()}
    function moveHighlight(delta) {revealRequested(0,height)}
    function startRecording(id) {recordingId=id;draftKey="";draftModifiers=[];recordError="";capture.forceActiveFocus()}
    function finishRecording() {recordingId="";recordError="";search.forceActiveFocus()}
    function modifiersOf(event) {
        let mods=[]
        if(event.modifiers & Qt.ShiftModifier)mods.push("shift")
        if(event.modifiers & Qt.ControlModifier)mods.push("ctrl")
        if(event.modifiers & Qt.AltModifier)mods.push("alt")
        if(event.modifiers & Qt.MetaModifier)mods.push("super")
        return mods
    }
    function keyName(event) {
        if(event.key>=Qt.Key_F1 && event.key<=Qt.Key_F35)return "F"+(event.key-Qt.Key_F1+1)
        const named={}
        named[Qt.Key_Space]="Space";named[Qt.Key_Return]="Return";named[Qt.Key_Enter]="Return";named[Qt.Key_Tab]="Tab"
        named[Qt.Key_Backspace]="BackSpace";named[Qt.Key_Delete]="Delete";named[Qt.Key_Left]="Left";named[Qt.Key_Right]="Right"
        named[Qt.Key_Up]="Up";named[Qt.Key_Down]="Down";named[Qt.Key_Home]="Home";named[Qt.Key_End]="End"
        named[Qt.Key_PageUp]="Page_Up";named[Qt.Key_PageDown]="Page_Down";named[Qt.Key_Minus]="minus";named[Qt.Key_Equal]="equal"
        named[Qt.Key_Comma]="comma";named[Qt.Key_Period]="period";named[Qt.Key_Slash]="slash";named[Qt.Key_Semicolon]="semicolon"
        named[Qt.Key_Apostrophe]="apostrophe";named[Qt.Key_BracketLeft]="bracketleft";named[Qt.Key_BracketRight]="bracketright";named[Qt.Key_QuoteLeft]="grave"
        if(named[event.key])return named[event.key]
        if(event.key>=Qt.Key_A && event.key<=Qt.Key_Z)return String.fromCharCode(event.key)
        if(event.key>=Qt.Key_0 && event.key<=Qt.Key_9)return String.fromCharCode(event.key)
        return ""
    }
    function textOf(binding) {return binding ? binding.modifiers.map(function(m){return m.charAt(0).toUpperCase()+m.slice(1)}).concat([binding.key]).join(" + ") : "Not assigned"}
    function matches(value) {return (value || "").toLowerCase().indexOf(filter.toLowerCase())>=0}
    ShortcutInhibitor {
        id:inhibitor
        window:SettingsModel.nativeWindow
        enabled:page.recordingId!==""
        onCancelled: {page.recordError="Shortcut capture was cancelled by the desktop.";page.recordingId=""}
    }
    Timer {interval:15000;running:page.recordingId!=="";onTriggered:page.finishRecording()}
    Connections {target:ShortcutsService;function onCompleted(action,success){if(action==="apply" && success)page.finishRecording()}}
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {text:"Keyboard shortcuts";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:"See every active desktop shortcut and create shortcuts for SwiftShell, apps, windows and workspaces.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Row {
            spacing:6
            FlatButton {label:"Your shortcuts";emphasized:page.section==="managed";onActivated:page.section="managed"}
            FlatButton {label:"All desktop shortcuts";emphasized:page.section==="effective";onActivated:page.section="effective"}
            FlatButton {label:"Refresh";enabled:!ShortcutsService.busy;onActivated:ShortcutsService.refresh()}
            FlatButton {label:"Undo change";enabled:!ShortcutsService.busy && ShortcutsService.canUndo;onActivated:ShortcutsService.undo()}
        }
        Controls.TextField {
            id:search
            width:parent.width;height:Theme.controlHeight+8
            placeholderText:"Search actions or key combinations"
            text:page.filter
            onTextEdited:page.filter=text
            color:Theme.settingsText;placeholderTextColor:Theme.settingsMuted
            font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
            background:Rectangle {radius:Theme.controlRadius;color:Theme.settingsHover}
            leftPadding:10;rightPadding:10
        }
        Text {width:parent.width;visible:text!=="";wrapMode:Text.WordWrap;text:ShortcutsService.error || page.recordError || ShortcutsService.warnings.join("\n");color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        Rectangle {
            width:parent.width;height:recordColumn.implicitHeight+20
            visible:page.recordingId!==""
            radius:Theme.controlRadius;color:Theme.settingsSelected
            Column {
                id:recordColumn;x:10;y:10;width:parent.width-20;spacing:8
                Text {width:parent.width;wrapMode:Text.WordWrap;text:!inhibitor.active ? "Waiting for safe keyboard capture…" : page.draftKey ? page.textOf({modifiers:page.draftModifiers,key:page.draftKey}) : "Press a shortcut. Escape cancels.";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+2}
                Row {
                    spacing:6
                    FlatButton {label:ShortcutsService.busy ? "Applying…" : "Apply shortcut";enabled:inhibitor.active && page.draftKey!=="" && !ShortcutsService.busy;onActivated:ShortcutsService.apply(page.recordingId,page.draftModifiers,page.draftKey)}
                    FlatButton {label:"Cancel";onActivated:page.finishRecording()}
                }
            }
        }
        Item {
            id:capture
            width:1;height:1
            Keys.onPressed:function(event) {
                if(page.recordingId==="")return
                event.accepted=true
                if(event.key===Qt.Key_Escape){page.finishRecording();return}
                if(!inhibitor.active)return
                const name=page.keyName(event)
                if(!name)return
                page.draftModifiers=page.modifiersOf(event);page.draftKey=name
                page.recordError=page.draftModifiers.length===0 ? "Include Super, Ctrl or Alt to keep ordinary typing available." : ""
            }
        }
        Text {
            visible:page.section==="managed"
            width:parent.width;wrapMode:Text.WordWrap
            text:"Changes apply immediately and return when SwiftShell starts. Existing desktop shortcuts are never replaced."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Repeater {
            model:page.section==="managed" ? ShortcutsService.actions.filter(function(a){return page.matches(a.label+" "+a.category+" "+page.textOf(a.binding))}) : []
            delegate:SettingsRow {
                required property var modelData
                width:column.width
                label:modelData.label
                Row {
                    spacing:6
                    Text {width:160;anchors.verticalCenter:parent.verticalCenter;text:page.textOf(modelData.binding);elide:Text.ElideRight;color:modelData.binding && !modelData.active ? Theme.settingsMuted : Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                    FlatButton {label:modelData.binding ? "Change" : "Record";enabled:page.recordingId==="" && !ShortcutsService.busy;onActivated:page.startRecording(modelData.id)}
                    FlatButton {label:"Remove";enabled:modelData.binding!==null && modelData.binding!==undefined && page.recordingId==="" && !ShortcutsService.busy;onActivated:ShortcutsService.remove(modelData.id)}
                }
            }
        }
        Text {
            width:parent.width;visible:page.section==="effective";wrapMode:Text.WordWrap
            text:"Your existing desktop shortcuts are read-only here. Use Managed to record shortcuts for SwiftShell, applications and window actions."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Repeater {
            model:page.section==="effective" ? ShortcutsService.effective.filter(function(a){return page.matches(a.label+" "+a.chord+" "+a.scope)}) : []
            delegate:Column {
                required property var modelData
                width:column.width;spacing:3
                SettingsRow {
                    width:parent.width;label:modelData.label
                    Text {width:200;text:modelData.chord;elide:Text.ElideRight;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;verticalAlignment:Text.AlignVCenter;height:Theme.controlHeight}
                }
                Text {text:modelData.owner+" · "+modelData.scope+(modelData.flags ? " · "+modelData.flags : "");color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                Item {width:1;height:6}
            }
        }
    }
}
