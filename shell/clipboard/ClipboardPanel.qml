import QtQuick
import QtQuick.Controls.Basic as Controls
import "../components"
import "../services"
import "../themes"
import "../logic/clipboard.js" as Clipboard
Item {
    id:panel
    property bool detachedWindow:false
    property real maximumListHeight:340
    property string query:""
    property int selectedIndex:0
    property bool detaching:false
    readonly property var rows:ClipboardModel.items(query)
    signal detached()
    signal dismissed()
    implicitWidth:360
    implicitHeight:column.implicitHeight
    width:implicitWidth;height:implicitHeight
    function focusSearch(){search.forceActiveFocus()}
    function copySelected(){if(rows.length && ClipboardModel.copy(rows[Math.min(selectedIndex,rows.length-1)].id)){if(!detachedWindow)dismissed()}}
    Connections {
        target:ClipboardModel
        function onWindowCompleted(action,success) {
            if(action!=="prepare" || !panel.detaching)return
            panel.detaching=false
            if(success)panel.detached()
        }
    }
    onRowsChanged:selectedIndex=Math.min(selectedIndex,Math.max(0,rows.length-1))
    function diagnostics(){return {enabled:ClipboardModel.recording,available:ClipboardModel.available,count:ClipboardModel.entries.length,filtered:rows.length,detached:detachedWindow}}
    Column {
        id:column;width:panel.width;spacing:Theme.settingsSpacing+2
        Row {
            width:parent.width
            Text {
                width:parent.width-pin.width-clear.width
                text:"Clipboard";textFormat:Text.PlainText
                color:Theme.settingsText;font.family:Theme.settingsFontFamily
                font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium
            }
            FlatButton {id:clear;objectName:"clipboardClear";label:"Clear";enabled:ClipboardModel.entries.length>0;onActivated:ClipboardModel.clear()}
            FlatButton {id:pin;objectName:"clipboardDetach";visible:!panel.detachedWindow;width:visible ? implicitWidth : 0;label:"Keep open";enabled:!panel.detaching;onActivated:{if(ClipboardModel.windowOpen){ClipboardModel.showWindow();panel.detached()}else{panel.detaching=true;ClipboardModel.showWindow()}}}
        }
        SettingsToggle {
            objectName:"clipboardEnabled";width:parent.width
            label:"Remember copied text";checked:ClipboardModel.recording
            enabled:ClipboardModel.available || ClipboardModel.recording
            onToggled:function(value){SettingsStore.setClipboardHistory(value)}
        }
        Text {
            width:parent.width;wrapMode:Text.WordWrap
            text:!ClipboardModel.available ? "Clipboard tools are unavailable." : !ClipboardModel.recording ? "Turn on history to keep recent copied text in this session." : "Recent text stays in memory for 20 minutes. Passwords may be included if an app does not mark them as sensitive."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
        Rectangle {
            width:parent.width;height:34;radius:Theme.controlRadius;color:Theme.settingsHover
            visible:ClipboardModel.recording
            Text {anchors.fill:parent;anchors.leftMargin:10;verticalAlignment:Text.AlignVCenter;visible:search.text.length===0;text:"Search copied text";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
            TextInput {
                id:search;objectName:"clipboardSearch";anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10
                verticalAlignment:TextInput.AlignVCenter;clip:true;color:Theme.settingsText;selectionColor:Theme.settingsSelected;selectedTextColor:Theme.settingsText
                font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
                selectByMouse:true;onTextChanged:{panel.query=text;panel.selectedIndex=0}
                Keys.onDownPressed:{panel.selectedIndex=Math.min(panel.rows.length-1,panel.selectedIndex+1);list.positionViewAtIndex(panel.selectedIndex,ListView.Contain)}
                Keys.onUpPressed:{panel.selectedIndex=Math.max(0,panel.selectedIndex-1);list.positionViewAtIndex(panel.selectedIndex,ListView.Contain)}
                Keys.onReturnPressed:panel.copySelected()
                Keys.onEnterPressed:panel.copySelected()
                Keys.onEscapePressed:if(text.length)text="";else panel.dismissed()
            }
        }
        Text {
            visible:ClipboardModel.recording && panel.rows.length===0
            width:parent.width;topPadding:22;bottomPadding:22
            text:panel.query.length ? "No matching text" : "Your clipboard history is empty"
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
        }
        ListView {
            id:list;objectName:"clipboardHistoryList"
            width:parent.width;height:Math.min(contentHeight,panel.maximumListHeight)
            visible:ClipboardModel.recording && panel.rows.length>0
            model:panel.rows;clip:true;spacing:3;boundsBehavior:Flickable.StopAtBounds
            Controls.ScrollBar.vertical:Controls.ScrollBar {width:4;policy:Controls.ScrollBar.AsNeeded;contentItem:Rectangle {radius:2;color:Theme.settingsMuted;opacity:.45} background:Item {}}
            delegate:Item {
                id:entry;required property var modelData;required property int index
                objectName:"clipboardEntry-"+index
                width:list.width;height:64
                Rectangle {anchors.fill:parent;radius:Theme.controlRadius;color:panel.selectedIndex===entry.index ? Theme.settingsSelected : copyArea.containsMouse ? Theme.settingsHover : "transparent"}
                MouseArea {
                    id:copyArea;objectName:"clipboardCopy-"+entry.index
                    anchors.fill:parent;anchors.rightMargin:remove.width
                    hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                    activeFocusOnTab:true;Accessible.role:Accessible.Button;Accessible.name:"Copy clipboard item "+(entry.index+1)
                    onClicked:{panel.selectedIndex=entry.index;if(ClipboardModel.copy(entry.modelData.id) && !panel.detachedWindow)panel.dismissed()}
                    Keys.onReturnPressed:clicked(null)
                    Keys.onSpacePressed:clicked(null)
                    Column {
                        anchors.left:parent.left;anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;anchors.margins:10;spacing:4
                        Text {width:parent.width;text:Clipboard.preview(entry.modelData.text);textFormat:Text.PlainText;elide:Text.ElideRight;maximumLineCount:1;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                        Text {width:parent.width;text:Clipboard.meta(entry.modelData.text);textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                    }
                }
                FlatButton {
                    id:remove;objectName:"clipboardRemove-"+entry.index
                    anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;width:30;label:"×"
                    Accessible.name:"Remove clipboard item "+(entry.index+1)
                    onActivated:ClipboardModel.remove(entry.modelData.id)
                }
            }
        }
        Text {
            visible:ClipboardModel.notice.length>0 || ClipboardModel.windowError.length>0
            width:parent.width;wrapMode:Text.WordWrap;text:ClipboardModel.windowError || ClipboardModel.notice
            textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
        }
    }
}
