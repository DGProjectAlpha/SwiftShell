import QtQuick
QtObject {
    property var menu:null
    property bool visible:false
    property QtObject anchor:QtObject {property var window:null;property rect rect:Qt.rect(0,0,1,1)}
    function open(){visible=true}
    function close(){visible=false}
}
