import QtQuick
import QtQuick.Dialogs
ColorDialog {
    property string field: ""
    signal colorChosen(string field,string value)
    title: "Choose color"
    function hex(channel) { return Math.round(channel*255).toString(16).padStart(2,"0") }
    onAccepted: colorChosen(field,"#"+hex(selectedColor.r)+hex(selectedColor.g)+hex(selectedColor.b))
}
