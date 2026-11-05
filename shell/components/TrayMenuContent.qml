import QtQuick
import Quickshell
import "../logic/menu.js" as Menu
import "../themes"

FocusScope {
    id:content
    property var entries:[]
    property string heading:"Application actions"
    property bool canGoBack:false
    property int selectedIndex:-1
    signal activated(var entry)
    signal backRequested()
    signal closeRequested()
    signal revealRequested(var item)
    implicitWidth:300
    implicitHeight:column.implicitHeight
    activeFocusOnTab:true
    readonly property int rowCount:rows.count
    function selectFirst() {
        const current=Menu.values(entries);
        if(selectedIndex<0 || selectedIndex>=current.length || !Menu.selectable(current[selectedIndex]))selectedIndex=Menu.nextIndex(entries,-1,1);
    }
    function move(delta) {
        selectedIndex=Menu.nextIndex(entries,selectedIndex,delta);
        const item=selectedIndex>=0 ? rows.itemAt(selectedIndex) : null;
        if(item)revealRequested(item);
    }
    function activateSelected() {
        const current=Menu.values(entries),entry=current[selectedIndex];
        if(Menu.selectable(entry))activated(entry);
    }
    function geometry() {
        const result=[];
        for(let index=0;index<rows.count;index++) {
            const item=rows.itemAt(index),point=item.mapToItem(null,0,0);
            result.push({index:index,x:point.x,y:point.y,width:item.width,height:item.height,enabled:Menu.selectable(item.entry),separator:item.entry.isSeparator===true,submenu:item.entry.hasChildren===true,checkState:item.entry.checkState || 0,buttonType:item.entry.buttonType || 0});
        }
        if(canGoBack) {
            const point=backButton.mapToItem(null,0,0);
            result.push({index:-1,x:point.x,y:point.y,width:backButton.width,height:backButton.height,enabled:true});
        }
        return result;
    }
    onEntriesChanged:{selectedIndex=-1;Qt.callLater(selectFirst)}
    Component.onCompleted:Qt.callLater(selectFirst)
    Connections {
        target:content.entries && !Array.isArray(content.entries) && content.entries.values !== undefined && typeof content.entries.values!=="function" ? content.entries : null
        ignoreUnknownSignals:true
        function onValuesChanged(){Qt.callLater(content.selectFirst)}
    }
    Keys.onPressed:function(event) {
        const alt=(event.modifiers&Qt.AltModifier)!==0;
        if(event.key===Qt.Key_Escape) {if(canGoBack)backRequested();else closeRequested();}
        else if(event.key===Qt.Key_Left || event.key===Qt.Key_Backspace) {if(canGoBack)backRequested();else closeRequested();}
        else if(event.key===Qt.Key_Down || event.key===Qt.Key_Tab || alt && event.key===Qt.Key_J)move(1);
        else if(event.key===Qt.Key_Up || event.key===Qt.Key_Backtab || alt && event.key===Qt.Key_K)move(-1);
        else if(event.key===Qt.Key_Home){selectedIndex=-1;move(1);}
        else if(event.key===Qt.Key_End){selectedIndex=0;move(-1);}
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter || event.key===Qt.Key_Space || event.key===Qt.Key_Right)activateSelected();
        else if(event.text && !(event.modifiers&(Qt.ControlModifier|Qt.MetaModifier))) {
            const found=Menu.matchingIndex(entries,selectedIndex,event.text,alt);
            if(found<0)return;
            selectedIndex=found;
            const item=rows.itemAt(found);if(item)revealRequested(item);
            if(alt)activateSelected();
        } else return;
        event.accepted=true;
    }
    Column {
        id:column
        width:content.width
        spacing:2
        Row {
            width:parent.width;height:30
            FlatButton {id:backButton;visible:content.canGoBack;width:visible ? 28 : 0;height:28;label:"‹";Accessible.name:"Back to previous menu";onActivated:content.backRequested()}
            Text {
                width:parent.width-(content.canGoBack ? 36 : 4);height:parent.height
                text:content.heading;textFormat:Text.PlainText;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }
        Repeater {
            id:rows
            objectName:"trayMenuRows"
            model:content.entries
            delegate:Item {
                id:row
                required property var modelData
                required property int index
                readonly property var entry:modelData
                width:column.width
                height:entry.isSeparator===true ? 9 : Math.max(30,Theme.settingsFontSize+16)
                Rectangle {visible:row.entry.isSeparator===true;anchors.verticalCenter:parent.verticalCenter;x:8;width:parent.width-16;height:1;color:Theme.settingsMuted;opacity:.18}
                MouseArea {
                    id:button
                    anchors.fill:parent
                    visible:row.entry.isSeparator!==true
                    enabled:row.entry.enabled!==false
                    hoverEnabled:true
                    cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered:content.selectedIndex=row.index
                    onClicked:{content.selectedIndex=row.index;content.activated(row.entry)}
                    Accessible.role:row.entry.buttonType===QsMenuButtonType.CheckBox ? Accessible.CheckBox : row.entry.buttonType===QsMenuButtonType.RadioButton ? Accessible.RadioButton : Accessible.MenuItem
                    Accessible.name:Menu.caption(row.entry.text)
                    Accessible.checkable:row.entry.buttonType===QsMenuButtonType.CheckBox || row.entry.buttonType===QsMenuButtonType.RadioButton
                    Accessible.checked:row.entry.checkState===Qt.Checked
                    Rectangle {anchors.fill:parent;radius:Theme.controlRadius;color:content.selectedIndex===row.index || button.pressed ? Theme.settingsSelected : "transparent"}
                    Item {
                        x:7;anchors.verticalCenter:parent.verticalCenter;width:18;height:18
                        opacity:button.enabled ? 1 : .38
                        Image {
                            anchors.centerIn:parent;width:16;height:16
                            visible:row.entry.buttonType===QsMenuButtonType.None && row.entry.icon!==""
                            source:visible ? row.entry.icon : ""
                            sourceSize:Qt.size(Math.round(width*(content.Window.window ? content.Window.window.devicePixelRatio : 1)),Math.round(height*(content.Window.window ? content.Window.window.devicePixelRatio : 1)))
                            fillMode:Image.PreserveAspectFit
                        }
                        Rectangle {
                            anchors.centerIn:parent;width:12;height:12
                            visible:row.entry.buttonType===QsMenuButtonType.CheckBox || row.entry.buttonType===QsMenuButtonType.RadioButton
                            radius:row.entry.buttonType===QsMenuButtonType.RadioButton ? 6 : 2
                            color:"transparent";border.width:1;border.color:Theme.settingsText
                            Rectangle {anchors.centerIn:parent;width:6;height:6;radius:parent.radius===6 ? 3 : 1;visible:row.entry.checkState===Qt.Checked;color:Theme.settingsText}
                            Rectangle {anchors.centerIn:parent;width:7;height:2;radius:1;visible:row.entry.checkState===Qt.PartiallyChecked;color:Theme.settingsText}
                        }
                    }
                    Text {
                        x:31;anchors.verticalCenter:parent.verticalCenter
                        width:Math.max(0,parent.width-x-shortcut.width-25)
                        text:Menu.caption(row.entry.text);textFormat:Text.PlainText;elide:Text.ElideRight
                        color:Theme.settingsText;opacity:button.enabled ? 1 : .38
                        font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                    }
                    Text {
                        id:shortcut
                        anchors.right:parent.right;anchors.rightMargin:row.entry.hasChildren ? 25 : 10;anchors.verticalCenter:parent.verticalCenter
                        text:Menu.shortcut(row.entry.text);textFormat:Text.PlainText
                        color:Theme.settingsMuted;opacity:button.enabled ? 1 : .38;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
                    }
                    Text {
                        anchors.right:parent.right;anchors.rightMargin:9;anchors.verticalCenter:parent.verticalCenter
                        visible:row.entry.hasChildren===true;text:"›";color:Theme.settingsMuted;opacity:button.enabled ? 1 : .38;font.pixelSize:20
                    }
                }
            }
        }
        Text {
            width:parent.width;visible:content.rowCount===0;text:"Loading application actions…";textFormat:Text.PlainText
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            height:visible ? 34 : 0;verticalAlignment:Text.AlignVCenter
        }
    }
}
