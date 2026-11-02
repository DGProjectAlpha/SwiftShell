import QtQuick
import "../components"
import "../themes"

Item {
    id: list
    property var entries: []
    property int dropIndex: -1
    property string draggingKey: ""
    signal reordered(string key, int destination)
    signal removed(string key)
    implicitHeight: entries.length * 44
    height: implicitHeight
    function move(key, destination) {
        if (destination >= 0 && destination < entries.length)
            reordered(key, destination)
    }
    function geometry() {
        const result=[]
        for(let i=0;i<rows.count;i++) {
            const row=rows.itemAt(i),point=row.mapToItem(null,0,0)
            result.push({key:row.entry.key,x:point.x+20,y:point.y+20,width:40,height:40})
        }
        return result
    }
    KeyedModel { id: stable; entries: list.entries }
    Repeater {
        id:rows
        model: stable
        delegate: Item {
            id: row
            required property var entry
            required property int index
            width: list.width
            height: 44
            y: index * height
            z: handle.drag.active ? 2 : 0
            Rectangle {
                id: card
                width: row.width
                height: 40
                radius: Math.min(8, Theme.radius)
                color: handle.drag.active ? Theme.settingsSelected : Theme.settingsHover
                opacity: handle.drag.active ? .94 : 1
                MouseArea {
                    id: handle
                    objectName: "workspaceDrag-" + row.entry.key
                    width: 40; height: parent.height
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: card
                    drag.axis: Drag.YAxis
                    drag.smoothed:false
                    drag.minimumY: -row.y
                    drag.maximumY: list.height-row.y-row.height
                    onPressed: { list.draggingKey=row.entry.key; list.dropIndex=row.index }
                    onPositionChanged: {
                        if (pressed) {
                            const position=card.mapToItem(list,0,card.height/2)
                            list.dropIndex=Math.max(0,Math.min(list.entries.length-1,Math.floor(position.y/row.height)))
                        }
                    }
                    onReleased: {
                        const destination=list.dropIndex
                        card.y=0
                        list.dropIndex=-1;list.draggingKey=""
                        if (destination !== row.index) list.move(row.entry.key,destination)
                    }
                    onCanceled: { card.y=0;list.dropIndex=-1;list.draggingKey="" }
                    Text { anchors.centerIn: parent; text:"⠿";color:Theme.settingsMuted;font.pixelSize:20 }
                }
                Text {
                    anchors.left:parent.left;anchors.leftMargin:46
                    anchors.verticalCenter:parent.verticalCenter
                    width:Math.max(0,parent.width-170)
                    text:row.entry.name
                    elide:Text.ElideRight
                    color:Theme.settingsText
                    font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                }
                Text {
                    anchors.right:remove.left;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter
                    text:row.entry.active ? "Active" : row.entry.elsewhere ? "Other screen" : row.entry.windows===0 ? "Empty" : ""
                    color:Theme.settingsMuted;font.pixelSize:Theme.settingsFontSizeSmall
                }
                FlatButton {
                    id:remove
                    anchors.right:parent.right;anchors.rightMargin:4;anchors.verticalCenter:parent.verticalCenter
                    width:30;label:"×";Accessible.name:"Remove " + row.entry.name + " indicator"
                    onActivated:list.removed(row.entry.key)
                }
                activeFocusOnTab:true
                Accessible.role:Accessible.ListItem
                Accessible.name:row.entry.name + ". Alt J and K reorder."
                Keys.onPressed:function(event) {
                    if (!(event.modifiers & Qt.AltModifier)) return
                    if (event.key===Qt.Key_J) list.move(row.entry.key,row.index+1)
                    else if(event.key===Qt.Key_K) list.move(row.entry.key,row.index-1)
                    else return
                    event.accepted=true
                }
            }
        }
    }
    Rectangle {
        visible:list.dropIndex>=0
        x:0;y:list.dropIndex*44
        width:list.width;height:2;radius:1
        color:Theme.settingsText
    }
}
