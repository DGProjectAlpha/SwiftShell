import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Controls as ControlTypes
import Quickshell.Wayland
import "../components"
import "../services"
import "../themes"
Item {
    id:page
    property string query:""
    property string highlightId:"desktopShortcuts"
    property string filter:""
    property string recordingId:""
    property var draftModifiers:[]
    property string draftKey:""
    property string recordError:""
    property string recordingLabel:""
    property var returnFocus:null
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560
    implicitHeight:column.implicitHeight
    height:implicitHeight
    function recordingStatus() {return {active:inhibitor.active,id:recordingId,modifiers:draftModifiers,key:draftKey}}
    function focusHighlight() {search.forceActiveFocus()}
    function moveHighlight(delta) {revealRequested(0,height)}
    function startRecording(id,label) {
        returnFocus=page.Window.window ? page.Window.window.activeFocusItem : null
        recordingId=id;recordingLabel=label || "Shortcut";draftKey="";draftModifiers=[];recordError=""
        recorder.open()
    }
    function finishRecording() {
        recordingId="";recordError="";recorder.close()
        const target=returnFocus;returnFocus=null
        if(target && target.visible && target.enabled)target.forceActiveFocus();else search.forceActiveFocus()
    }
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
        onCancelled: {page.recordError="Shortcut capture was cancelled by the desktop.";page.recordingId="";recorder.close()}
    }
    Timer {interval:15000;running:page.recordingId!=="";onTriggered:page.finishRecording()}
    Connections {target:ShortcutsService;function onCompleted(action,success){if(action==="apply" && success)page.finishRecording()}}
    Column {
        id:column
        width:page.width
        spacing:Theme.settingsSpacing
        Text {text:"Keyboard shortcuts";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}

        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Search your desktop shortcuts and change their key combinations. Changes are saved to your desktop configuration.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}

        Row {
            spacing:6
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

        SettingsSection {
            sectionId:"shortcuts.desktop"
            searchKeywords:ShortcutsService.effective.map(function(action){return action.label+" "+action.chord}).join(" ")
            title:"Desktop shortcuts"
            description:"All effective keyboard shortcuts from your desktop."
            searchQuery:page.filter || page.query
            controlIds:["desktopShortcuts"]
            width:parent.width
            defaultExpanded:true
            Text {
                width:parent.width;wrapMode:Text.WordWrap
                text:ShortcutsService.sourceEditable+" shortcuts can be changed here. Generated shortcuts remain visible with an explanation."
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
            Repeater {
                model:ShortcutsService.effective.filter(function(a){return page.matches(a.label+" "+a.chord+" "+a.scope)})
                delegate:Column {
                    required property var modelData
                    width:column.width;spacing:3
                    SettingsRow {
                        width:parent.width;label:modelData.label
                        Row {
                            spacing:8
                            Text {width:160;text:modelData.chord;elide:Text.ElideRight;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;verticalAlignment:Text.AlignVCenter;height:Theme.controlHeight}
                            FlatButton {label:"Change";visible:modelData.editable===true;enabled:!ShortcutsService.busy && page.recordingId==="";Accessible.name:"Change "+modelData.label;onActivated:page.startRecording(modelData.sourceId,modelData.label)}
                        }
                    }
                    Text {width:parent.width;wrapMode:Text.WordWrap;text:modelData.editable ? "Desktop · "+modelData.scope+(modelData.flags ? " · "+modelData.flags : "") : "This shortcut is generated by your desktop configuration and cannot be changed individually yet.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                    Item {width:1;height:6}
                }
            }
        }
    }
    Controls.Popup {
        id:recorder
        objectName:"desktopShortcutRecorder"
        parent:ControlTypes.Overlay.overlay
        Component.onCompleted:if(recorder["popupType"]!==undefined)recorder["popupType"]=Controls.Popup.Item
        x:parent ? Math.round((parent.width-width)/2) : 0
        y:parent ? Math.round((parent.height-height)/2) : 0
        width:Math.min(430,parent ? parent.width-32 : 430)
        padding:18;modal:true;dim:false;focus:true
        closePolicy:Controls.Popup.CloseOnEscape
        onOpened:capture.forceActiveFocus()
        onClosed:if(page.recordingId!=="")page.finishRecording()
        background:Rectangle {radius:Theme.radius;color:Theme.settingsPopupSurface}
        contentItem:Column {
            spacing:12
            Text {width:parent.width;text:"Change shortcut";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+3;font.weight:Font.Medium}
            Text {width:parent.width;text:page.recordingLabel;textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSize}
            Item {
                id:capture
                width:parent.width;height:50
                focus:true
                Text {anchors.fill:parent;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap;text:!inhibitor.active ? "Waiting for safe keyboard capture…" : page.draftKey ? page.textOf({modifiers:page.draftModifiers,key:page.draftKey}) : "Press a shortcut. Escape cancels.";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+3}
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
            Text {width:parent.width;wrapMode:Text.WordWrap;visible:text!=="";text:ShortcutsService.error || page.recordError;color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"The original action stays the same. Undo is available after applying.";color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall}
            Row {
                spacing:8
                FlatButton {label:"Cancel";onActivated:page.finishRecording()}
                FlatButton {objectName:"applyDesktopShortcut";label:ShortcutsService.busy ? "Applying…" : "Apply shortcut";emphasized:true;enabled:inhibitor.active && page.draftKey!=="" && page.recordError==="" && !ShortcutsService.busy;onActivated:ShortcutsService.apply(page.recordingId,page.draftModifiers,page.draftKey)}
            }
        }
    }
}
