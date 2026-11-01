import QtQuick
import QtTest

TestCase {
    name: "RequiredDialogs"
    when: windowShown

    function test_color_picker_returns_valid_opaque_hex() {
        var component=Qt.createComponent("../../shell/settings/ColorPicker.qml")
        compare(component.status,Component.Ready,component.errorString())
        var picker=component.createObject(this,{field:"manualText",selectedColor:Qt.rgba(.1,.2,.3,.4)})
        var chosen=""
        picker.colorChosen.connect(function(field,value){chosen=value})
        picker.accepted()
        compare(chosen,"#1a334d")
        picker.destroy()
    }

    function test_image_dialog_compiles_when_dependency_is_installed() {
        var path = Qt.resolvedUrl("../../shell/settings/ImageDialog.qml")
        var component = Qt.createComponent(path)
        compare(component.status, Component.Ready, component.errorString())
    }
}
