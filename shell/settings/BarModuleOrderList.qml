import QtQuick
import "../components"
import "../logic/bar.js" as Bar
import "../themes"
Item {
    id:list
    property var entries:[]
    property var hidden:[]
    property string sides:"{}"
    property string draggingId:""
    property int dropIndex:-1
    property var scrollViewport:null
    readonly property int rowHeight:width<360 ? 78 : 44
    signal reordered(string id,int destination)
    signal visibilityToggled(string id)
    signal sideChosen(string id,string side)
    implicitHeight:entries.length*rowHeight
    function move(id,destination) {
        if(entries.indexOf(id)>=0 && destination>=0 && destination<entries.length && entries.indexOf(id)!==destination)reordered(id,destination)
    }
    function viewport() {
        let item=list.parent
        while(item) {if(item.contentY!==undefined && item.contentHeight!==undefined && item.flickableDirection!==undefined)return item;item=item.parent}
        return null
    }
    function geometry() {
        const out=[]
        for(let i=0;i<rows.count;i++) {const row=rows.itemAt(i),p=row.mapToItem(null,18,row.height/2);out.push({id:row.entry,x:p.x,y:p.y,height:row.height})}
        return out
    }
    KeyedModel {id:stable;entries:list.entries}
    Repeater {
        id:rows;model:stable
        delegate:Item {
            id:row
            required property string entry
            required property int index
            property bool cancelled:false
            width:list.width;height:list.rowHeight;y:index*height
            z:handle.drag.active ? 2 : 0
            function reset(){card.y=0;list.draggingId="";list.dropIndex=-1;list.scrollViewport=null}
            function updateDrop(){const p=card.mapToItem(list,0,card.height/2);list.dropIndex=Math.max(0,Math.min(list.entries.length-1,Math.floor(p.y/list.rowHeight)))}
            Rectangle {
                id:card;width:row.width;height:row.height-4
                radius:Theme.controlRadius;color:handle.drag.active ? Theme.settingsSelected : Theme.settingsHover
                MouseArea {
                    id:handle;objectName:"barModuleDrag-"+row.entry
                    width:36;height:parent.height
                    hoverEnabled:true;preventStealing:true;activeFocusOnTab:true
                    cursorShape:drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target:row.cancelled ? null : card;drag.axis:Drag.YAxis;drag.smoothed:false
                    drag.minimumY:-row.y;drag.maximumY:list.height-row.y-row.height
                    Accessible.role:Accessible.Button
                    Accessible.name:"Reorder "+Bar.moduleName(row.entry)
                    Accessible.description:"Drag to reorder. Alt J moves later; Alt K moves earlier."
                    onPressed:{row.cancelled=false;forceActiveFocus();list.draggingId=row.entry;list.dropIndex=row.index;list.scrollViewport=list.viewport()}
                    onPositionChanged:if(pressed && !row.cancelled)row.updateDrop()
                    onReleased:{const destination=list.dropIndex;row.reset();if(!row.cancelled)list.move(row.entry,destination)}
                    onCanceled:{row.cancelled=true;row.reset()}
                    Keys.onEscapePressed:{row.cancelled=true;row.reset()}
                    Keys.onPressed:function(event) {
                        if(!(event.modifiers & Qt.AltModifier))return
                        if(event.key===Qt.Key_J)list.move(row.entry,row.index+1)
                        else if(event.key===Qt.Key_K)list.move(row.entry,row.index-1)
                        else return
                        event.accepted=true
                    }
                    Text {anchors.centerIn:parent;text:"⠿";color:handle.activeFocus ? Theme.settingsText : Theme.settingsMuted;font.pixelSize:20}
                }
                Text {
                    x:42;y:0;width:list.width<360 ? parent.width-50 : Math.max(30,parent.width-controls.width-56);height:36
                    verticalAlignment:Text.AlignVCenter;text:Bar.moduleName(row.entry);elide:Text.ElideRight
                    color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                }
                Row {
                    id:controls;x:list.width<360 ? 42 : parent.width-width-6;y:list.width<360 ? 36 : 2;spacing:6
                    FlatButton {objectName:"barModuleVisibility-"+row.entry;width:56;label:list.hidden.indexOf(row.entry)>=0 ? "Show" : "Hide";Accessible.name:label+" "+Bar.moduleName(row.entry);onActivated:list.visibilityToggled(row.entry)}
                    ChoiceBox {
                        objectName:"barModuleSide-"+row.entry
                        width:100;height:Theme.controlHeight
                        choices:[{label:"Left",value:"left"},{label:"Center",value:"center"},{label:"Right",value:"right"}]
                        selectedValue:Bar.moduleSide(row.entry,list.sides,list.entries)
                        onChosen:function(value){list.sideChosen(row.entry,value)}
                    }
                }
            }
            Timer {
                interval:40;repeat:true
                running:handle.drag.active && list.scrollViewport!==null
                onTriggered: {
                    const view=list.scrollViewport,p=handle.mapToItem(view,handle.mouseX,handle.mouseY)
                    const delta=p.y<32 ? -12 : p.y>view.height-32 ? 12 : 0
                    if(!delta)return
                    const before=view.contentY
                    view.contentY=Math.max(0,Math.min(view.contentHeight-view.height,before+delta))
                    card.y=Math.max(handle.drag.minimumY,Math.min(handle.drag.maximumY,card.y+view.contentY-before))
                    row.updateDrop()
                }
            }
        }
    }
    Rectangle {visible:list.dropIndex>=0;x:0;y:list.dropIndex*list.rowHeight;width:list.width;height:2;color:Theme.settingsText;z:3}
}
