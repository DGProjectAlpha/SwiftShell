import QtQuick
import QtTest

TestCase {
    name: "RequiredDialogs"
    when: windowShown

    function test_image_dialog_compiles_when_dependency_is_installed() {
        var path = Qt.resolvedUrl("../../shell/settings/ImageDialog.qml")
        var component = Qt.createComponent(path)
        compare(component.status, Component.Ready, component.errorString())
    }
}
