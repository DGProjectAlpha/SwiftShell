import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Controls as ControlTypes
import "../components"
import "../themes"

Item {
    id: picker
    property string field: ""
    property color selectedColor: "#161616"
    property real hue: 0
    property real saturation: 0
    property real brightness: 0
    property bool invalidHex: false
    readonly property color draftColor: Qt.hsva(hue,saturation,brightness,1)
    readonly property bool opened: dialog.opened
    signal colorChosen(string field,string value)
    signal accepted()
    signal rejected()

    function hex(channel) { return Math.round(channel*255).toString(16).padStart(2,"0") }
    function colorHex(color) { return "#"+hex(color.r)+hex(color.g)+hex(color.b) }
    function setDraft(color) {
        if(color.hsvHue>=0) hue=color.hsvHue
        saturation=color.hsvSaturation
        brightness=color.hsvValue
        invalidHex=false
    }
    function fromHex(text) {
        const value=String(text).replace(/^#/,"")
        return Qt.rgba(parseInt(value.slice(0,2),16)/255,parseInt(value.slice(2,4),16)/255,parseInt(value.slice(4,6),16)/255,1)
    }
    function applyHex(text) {
        const value=String(text).trim().replace(/^#/,"")
        if(!/^[0-9a-fA-F]{6}$/.test(value)) { invalidHex=true;return false }
        setDraft(fromHex(value))
        return true
    }
    function geometry() {
        function box(item) { const point=item.mapToItem(dialog.parent,0,0);return {x:point.x,y:point.y,width:item.width,height:item.height} }
        return {x:dialog.x,y:dialog.y,width:dialog.width,height:dialog.height,spectrum:box(spectrum),hue:box(hueTrack),accept:box(acceptButton),cancel:box(cancelButton),draft:colorHex(draftColor)}
    }
    function open() { setDraft(selectedColor);dialog.open() }
    function close() { dialog.close() }
    function accept() {
        if(!applyHex(hexField.text)) return
        selectedColor=draftColor
        accepted()
    }
    function reject() { rejected();dialog.close() }
    onAccepted: { colorChosen(field,colorHex(selectedColor));dialog.close() }

    Controls.Popup {
        id: dialog
        objectName:"colorPickerPopup"
        parent: ControlTypes.Overlay.overlay
        // Item is the default on older Qt; explicitly retain it on Qt 6.8+.
        Component.onCompleted: { if(dialog["popupType"] !== undefined) dialog["popupType"]=Controls.Popup.Item }
        x: parent ? Math.round((parent.width-width)/2) : 0
        y: parent ? Math.round((parent.height-height)/2) : 0
        width: Math.min(360,parent ? parent.width-40 : 360)
        padding:14
        modal:true
        dim:false
        focus:true
        closePolicy:Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
        onOpened: spectrum.forceActiveFocus()
        background:Rectangle { radius:Theme.radius;color:Theme.settingsPopupSurface }
        contentItem:Column {
            spacing:8
            Text {
                text:"Choose color"
                color:Theme.settingsText
                font.family:Theme.settingsFontFamily
                font.pixelSize:Theme.settingsFontSize+2
                font.weight:Font.Medium
            }
            Item {
                id:spectrum
                objectName:"colorSpectrum"
                width:parent.width
                height:Math.max(64,Math.min(156,dialog.parent ? dialog.parent.height-370 : 156))
                activeFocusOnTab:true
                Accessible.role:Accessible.Slider
                Accessible.name:"Saturation and brightness"
                Accessible.description:"Alt H and L adjust saturation. Alt J and K adjust brightness."
                Rectangle { anchors.fill:parent;color:Qt.hsva(picker.hue,1,1,1) }
                Rectangle {
                    anchors.fill:parent
                    gradient:Gradient {
                        orientation:Gradient.Horizontal
                        GradientStop {position:0;color:"white"}
                        GradientStop {position:1;color:"transparent"}
                    }
                }
                Rectangle {
                    anchors.fill:parent
                    gradient:Gradient {
                        GradientStop {position:0;color:"transparent"}
                        GradientStop {position:1;color:"black"}
                    }
                }
                Rectangle {
                    width:10;height:10;radius:5
                    x:picker.saturation*(parent.width-1)-5
                    y:(1-picker.brightness)*(parent.height-1)-5
                    color:"transparent";border.width:2;border.color:"white"
                    Rectangle {anchors.fill:parent;anchors.margins:-1;radius:6;color:"transparent";border.width:1;border.color:"#303030"}
                }
                function position(px,py) {
                    picker.saturation=Math.max(0,Math.min(1,px/width))
                    picker.brightness=1-Math.max(0,Math.min(1,py/height))
                    picker.invalidHex=false
                }
                Keys.onPressed:function(event) {
                    const alt=(event.modifiers & Qt.AltModifier)!==0
                    if(event.key===Qt.Key_Left || (alt && event.key===Qt.Key_H)) picker.saturation=Math.max(0,picker.saturation-.02)
                    else if(event.key===Qt.Key_Right || (alt && event.key===Qt.Key_L)) picker.saturation=Math.min(1,picker.saturation+.02)
                    else if(event.key===Qt.Key_Up || (alt && event.key===Qt.Key_K)) picker.brightness=Math.min(1,picker.brightness+.02)
                    else if(event.key===Qt.Key_Down || (alt && event.key===Qt.Key_J)) picker.brightness=Math.max(0,picker.brightness-.02)
                    else return
                    event.accepted=true
                }
                MouseArea {
                    anchors.fill:parent
                    cursorShape:Qt.CrossCursor
                    onPressed:function(mouse){spectrum.forceActiveFocus();spectrum.position(mouse.x,mouse.y)}
                    onPositionChanged:function(mouse){if(pressed)spectrum.position(mouse.x,mouse.y)}
                }
            }
            Item {
                id:hueTrack
                objectName:"colorHue"
                width:parent.width;height:20
                activeFocusOnTab:true
                Accessible.role:Accessible.Slider
                Accessible.name:"Hue"
                Rectangle {
                    anchors.fill:parent;anchors.topMargin:4;anchors.bottomMargin:4;radius:3
                    gradient:Gradient {
                        orientation:Gradient.Horizontal
                        GradientStop {position:0;color:"#ff0000"}
                        GradientStop {position:1/6;color:"#ffff00"}
                        GradientStop {position:2/6;color:"#00ff00"}
                        GradientStop {position:3/6;color:"#00ffff"}
                        GradientStop {position:4/6;color:"#0000ff"}
                        GradientStop {position:5/6;color:"#ff00ff"}
                        GradientStop {position:1;color:"#ff0000"}
                    }
                }
                Rectangle {x:picker.hue*(parent.width-8);width:8;height:parent.height;radius:4;color:"transparent";border.width:hueTrack.activeFocus ? 3 : 2;border.color:Theme.settingsText}
                Keys.onPressed:function(event) {
                    const alt=(event.modifiers & Qt.AltModifier)!==0
                    if(event.key===Qt.Key_Left || (alt && event.key===Qt.Key_H)) picker.hue=Math.max(0,picker.hue-.01)
                    else if(event.key===Qt.Key_Right || (alt && event.key===Qt.Key_L)) picker.hue=Math.min(1,picker.hue+.01)
                    else return
                    event.accepted=true
                }
                MouseArea {
                    anchors.fill:parent
                    cursorShape:Qt.PointingHandCursor
                    onPressed:function(mouse){hueTrack.forceActiveFocus();picker.hue=Math.max(0,Math.min(1,mouse.x/width))}
                    onPositionChanged:function(mouse){if(pressed)picker.hue=Math.max(0,Math.min(1,mouse.x/width))}
                }
            }
            Row {
                width:parent.width;spacing:8
                Rectangle {width:30;height:30;radius:4;color:picker.draftColor;anchors.verticalCenter:parent.verticalCenter}
                Controls.TextField {
                    id:hexField
                    objectName:"colorHex"
                    width:parent.width-38;height:34
                    text:picker.colorHex(picker.draftColor)
                    color:Theme.settingsText
                    selectionColor:Theme.settingsSelected
                    selectedTextColor:Theme.settingsText
                    font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                    Accessible.name:"Hexadecimal color"
                    onEditingFinished:picker.applyHex(text)
                    onAccepted:picker.accept()
                    background:Rectangle {radius:Theme.controlRadius;color:Theme.settingsHover;border.width:hexField.activeFocus ? 1 : 0;border.color:Theme.settingsMuted}
                }
            }
            Text {
                visible:picker.invalidHex
                text:"Enter six hexadecimal digits, such as #808080."
                width:parent.width;wrapMode:Text.WordWrap
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
            Row {
                spacing:8
                Repeater {
                    model:["#161616","#333333","#666666","#999999","#cccccc","#f2f2f2"]
                    delegate:MouseArea {
                        required property string modelData
                        width:26;height:24;cursorShape:Qt.PointingHandCursor;activeFocusOnTab:true
                        Accessible.role:Accessible.Button;Accessible.name:"Use "+modelData
                        onClicked:picker.setDraft(picker.fromHex(modelData))
                        Keys.onSpacePressed:picker.setDraft(picker.fromHex(modelData))
                        Keys.onReturnPressed:picker.setDraft(picker.fromHex(modelData))
                        Rectangle {anchors.fill:parent;radius:4;color:parent.modelData;border.width:parent.activeFocus ? 2 : 0;border.color:Theme.settingsText}
                    }
                }
            }
            Row {
                width:parent.width;spacing:8;layoutDirection:Qt.RightToLeft
                FlatButton {id:acceptButton;objectName:"colorAccept";label:"Use color";emphasized:true;onActivated:picker.accept()}
                FlatButton {id:cancelButton;objectName:"colorCancel";label:"Cancel";onActivated:picker.reject()}
            }
        }
    }
}
