import QtQuick
import QtTest

TestCase {
    name: "ImplicitSize"
    when: windowShown

    function failureText(qml) {
        try {
            var object = Qt.createQmlObject(qml, this, "probe")
            if (object)
                object.destroy()
            return ""
        } catch (error) {
            return String(error)
        }
    }

    function test_confirmed_startup_assignments_are_rejected() {
        var calendar = failureText("import QtQuick\nColumn { implicitWidth: Math.max(10, 20); width: implicitWidth }")
        verify(calendar.indexOf("Invalid property assignment: \"implicitWidth\" is a read-only property") !== -1)

        var control = failureText("import QtQuick\nColumn { implicitWidth: 248; width: implicitWidth }")
        verify(control.indexOf("Invalid property assignment: \"implicitWidth\" is a read-only property") !== -1)

        var loaderHeight = failureText("import QtQuick\nLoader { implicitHeight: item ? item.implicitHeight : 0 }")
        verify(loaderHeight.indexOf("Invalid property assignment: \"implicitHeight\" is a read-only property") !== -1)

        var loaderWidth = failureText("import QtQuick\nLoader { implicitWidth: item ? item.implicitWidth : 0 }")
        verify(loaderWidth.indexOf("Invalid property assignment: \"implicitWidth\" is a read-only property") !== -1)
    }

    function test_implicit_size_item_subclasses_reject_assignment() {
        var types = ["Row", "Grid", "Flow", "Text", "TextInput", "TextEdit", "Image"]
        for (var index = 0; index < types.length; index++) {
            var message = failureText("import QtQuick\n" + types[index] + " { implicitWidth: 12 }")
            verify(message.indexOf("read-only property") !== -1)
        }
    }

    function test_plain_items_accept_implicit_size() {
        var types = ["Item", "Rectangle", "MouseArea", "FocusScope"]
        for (var index = 0; index < types.length; index++) {
            compare(failureText("import QtQuick\n" + types[index] + " { implicitWidth: 12; implicitHeight: 8 }"), "")
        }
        compare(failureText("import QtQuick\nimport QtQuick.Layouts\nRowLayout { implicitWidth: 12; implicitHeight: 8 }"), "")
        compare(failureText("import QtQuick\nimport QtQuick.Layouts\nColumnLayout { implicitHeight: 28 }"), "")
        compare(failureText("import QtQuick\nRow { width: implicitWidth }"), "")
        compare(failureText("import QtQuick\nItem { onImplicitWidthChanged: {} }"), "")
    }

    function test_panel_wrapper_keeps_loader_size() {
        var panel = Qt.createQmlObject("import QtQuick\n" +
            "Item {\n" +
            "    implicitWidth: Math.max(196, header.implicitWidth)\n" +
            "    implicitHeight: column.implicitHeight\n" +
            "    width: implicitWidth\n" +
            "    height: implicitHeight\n" +
            "    Column {\n" +
            "        id: column\n" +
            "        width: parent.width\n" +
            "        Row {\n" +
            "            id: header\n" +
            "            Rectangle { implicitWidth: 70; width: 70; implicitHeight: 28; height: 28 }\n" +
            "            Rectangle { implicitWidth: 90; width: 90; implicitHeight: 28; height: 28 }\n" +
            "            Rectangle { implicitWidth: 50; width: 50; implicitHeight: 28; height: 28 }\n" +
            "        }\n" +
            "        Rectangle { width: parent.width; implicitHeight: 20; height: 20 }\n" +
            "    }\n" +
            "}", this, "calendar-shape")
        compare(panel.implicitWidth, 210)
        compare(panel.width, 210)
        compare(panel.implicitHeight, 48)
        panel.destroy()

        var loaded = Qt.createQmlObject("import QtQuick\n" +
            "Item {\n" +
            "    implicitWidth: 248\n" +
            "    implicitHeight: column.implicitHeight\n" +
            "    width: implicitWidth\n" +
            "    height: implicitHeight\n" +
            "    Column {\n" +
            "        id: column\n" +
            "        width: parent.width\n" +
            "        Loader {\n" +
            "            width: parent.width\n" +
            "            sourceComponent: Column {\n" +
            "                Rectangle { implicitWidth: 10; implicitHeight: 18; width: 10; height: 18 }\n" +
            "                Rectangle { implicitWidth: 10; implicitHeight: 22; width: parent.width; height: 22 }\n" +
            "            }\n" +
            "        }\n" +
            "    }\n" +
            "}", this, "control-shape")
        compare(loaded.implicitWidth, 248)
        compare(loaded.width, 248)
        compare(loaded.implicitHeight, 40)
        compare(loaded.height, 40)
        loaded.destroy()
    }
}
