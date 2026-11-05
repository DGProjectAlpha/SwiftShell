import QtQuick
QtObject {
    property var menu:null
    readonly property var children:menu && menu.children !== undefined ? menu.children : []
}
