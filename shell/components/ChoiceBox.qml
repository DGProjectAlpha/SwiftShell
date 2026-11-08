import QtQuick
import QtQuick.Controls.Basic as Controls
import "../themes"
import "../services"

Controls.ComboBox {
    id: control
    property var choices: []
    property var selectedValue: null
    property string customLabel: ""
    readonly property var resolvedChoices: {
        if (selectedValue === null || selectedValue === undefined || choices.some(function(c){return c.value===selectedValue})) return choices
        return choices.concat([{label:customLabel || String(selectedValue),value:selectedValue}])
    }
    signal chosen(var value)
    model: resolvedChoices
    textRole: "label"
    valueRole: "value"
    currentIndex: {
        for (let i = 0; i < resolvedChoices.length; i++) {
            if (resolvedChoices[i].value === selectedValue) return i
        }
        return -1
    }
    opacity: enabled ? 1 : .45
    width: 240
    height: Theme.controlHeight + 6
    font.family: Theme.settingsFontFamily
    font.pixelSize: Theme.settingsFontSize
    font.weight: Theme.fontWeight
    onActivated: chosen(currentValue)
    background: Rectangle {
        radius: Theme.controlRadius
        color: control.down ? Qt.rgba(.5,.5,.5,.18) : Qt.rgba(.5,.5,.5,control.hovered ? .12 : .07)
        border.width: control.activeFocus ? 1 : 0
        border.color: Theme.controlAccent
    }
    contentItem: Text {
        leftPadding: 10
        rightPadding: 26
        text: control.displayText
        textFormat:Text.PlainText
        verticalAlignment: Text.AlignVCenter
        font: control.font
        color: control.enabled ? Theme.settingsText : Theme.settingsMuted
        elide: Text.ElideRight
    }
    indicator: Text {
        x: control.width - 22
        y: (control.height-height)/2
        text: "⌄"
        color: Theme.settingsMuted
    }
    delegate: Controls.ItemDelegate {
        id:delegateControl
        width: control.width
        text: modelData.label
        font: control.font
        highlighted: control.highlightedIndex === index
        contentItem: Text { textFormat:Text.PlainText; text: modelData.label; color: Theme.settingsText; font: control.font; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Theme.controlRadius; color: delegateControl.highlighted ? Theme.settingsSelected : "transparent" }
    }
    popup: Controls.Popup {
        id:choicePopup
        property real reveal:0
        y: control.height + 4
        width: control.width
        padding: 5
        implicitHeight: Math.min(260, list.contentHeight + 10)
        height:Math.max(1,implicitHeight*reveal)
        clip:true
        enter:Transition {NumberAnimation {target:choicePopup;property:"reveal";to:1;duration:Theme.motionOpen;easing.type:Easing.OutCubic}}
        exit:Transition {NumberAnimation {target:choicePopup;property:"reveal";to:0;duration:Theme.motionClose;easing.type:Easing.InCubic}}
        contentItem: ListView {
            id: list
            clip: true
            interactive:false
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            WheelHandler {
                target:null
                acceptedDevices:PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel:function(event) {
                    const delta=event.pixelDelta.y || event.angleDelta.y/120*Theme.controlHeight*3
                    list.contentY=Math.max(0,Math.min(Math.max(0,list.contentHeight-list.height),list.contentY-delta))
                    event.accepted=true
                }
            }
        }
        background: Rectangle { radius: Theme.controlRadius + 2; color: Theme.settingsPopupSurface }
    }
}
