import QtQuick
QtObject {
    default property list<QtObject> regions:[]
    property int intersection:0
    property Item item:null
    property int radius:0
    property int x:0
    property int y:0
    property int width:0
    property int height:0
    signal changed()
}
