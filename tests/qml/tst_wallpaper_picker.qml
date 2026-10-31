import QtQuick
import QtTest

TestCase {
    name: "WallpaperPickerDependencies"
    when: windowShown

    function requireReady(relativePath) {
        var component = Qt.createComponent(Qt.resolvedUrl("../../" + relativePath))
        compare(component.status, Component.Ready, component.errorString())
    }

    function test_folder_dialog_compiles() {
        requireReady("shell/settings/FolderPicker.qml")
    }

    function test_folder_scanner_compiles() {
        requireReady("shell/settings/FolderScanner.qml")
    }
}
