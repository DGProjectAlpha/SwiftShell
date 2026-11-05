import QtQuick
import QtQuick.Controls.Basic as Controls
import Quickshell
import "../components"
import "../services"
import "../themes"
import "../logic/launcher.js" as Launcher
import "../logic/search.js" as Search
import "../logic/settingsNav.js" as Navigation

Rectangle {
    id: card
    objectName: "spotlightCard"
    radius: Theme.radius
    color: Theme.floaterSurface
    property var appRows: []
    property var providerRows: []
    property var favoriteEntry: null
    readonly property bool canReorder:LauncherModel.gridMode==="favorites" && !searching
    property string draggedFavorite:""
    property int favoriteDropIndex:-1
    property bool favoriteDragging:false
    readonly property bool searchHasFocus: field.activeFocus
    readonly property bool searching: LauncherModel.query.trim() !== ""
    readonly property int columns: Math.max(1,Math.floor(appGrid.width / 96))
    readonly property var quickActions: [
        {kind:"settings",id:"settings",name:"Settings",icon:"preferences-system"},
        {kind:"power",id:"lock",name:"Lock",icon:"system-lock-screen"},
        {kind:"power",id:"suspend",name:"Suspend",icon:"system-suspend"},
        {kind:"power",id:"reboot",name:"Restart",icon:"system-reboot"},
        {kind:"power",id:"poweroff",name:"Shut down",icon:"system-shutdown"}
    ]
    readonly property int selectionCount: providerRows.length + appRows.length + quickActions.length
    signal closeRequested()
    function focusInput() { field.forceActiveFocus(); }
    function releaseInput() { field.focus=false; favoriteMenu.close();endFavoriteDrag(false); }
    function iconFor(name) {return Launcher.cachedIconSource(name,function(value){return Quickshell.iconPath(value,true);});}
    function rebuild() {
        const query=LauncherModel.query.trim();
        const apps=LauncherModel.applications;
        const found=query ? Launcher.rank(apps,query).map(function(app){return Launcher.appRow(app,"Results");}) : Launcher.gridRows(apps,LauncherModel.gridMode,SettingsStore.pinnedIds,LauncherModel.recentIds);
        const providers=[];
        if(query) {
            const immediate=Search.providerResult(query);
            if(immediate) providers.push(immediate);
            const clipboard=DesktopTools.clipboardResults(query)
            for(const row of clipboard)providers.push(row)
            const windows=LauncherModel.windowResults(query)
            for(const row of windows)providers.push(row)
            if(/^(screenshot|capture)(?:\s|$)/i.test(query)) {
                if(DesktopTools.regionAvailable)providers.unshift({kind:"screenshot",id:"capture-region",name:"Screenshot a region",detail:"Select an area · Preview, copy or save PNG",mode:"region"})
                if(DesktopTools.screenshotAvailable)providers.push({kind:"screenshot",id:"capture-output",name:"Screenshot this display",detail:"Preview, copy or save PNG",mode:"output"})
            }
            const controls=Navigation.filterControls(query);
            const used={};
            for(let index=0;index<controls.length && providers.length<6;index++) {
                const control=controls[index];
                if(used[control.category]) continue;
                used[control.category]=true;
                providers.push({kind:"setting-result",id:"setting-"+control.category,category:control.category,controlId:control.id,name:control.label,detail:"Settings · "+control.section,icon:"preferences-system",section:"Settings"});
            }
            for(let i=0;i<quickActions.length;i++) {
                const action=quickActions[i];
                if(action.name.toLowerCase().indexOf(query.toLowerCase())>=0 || action.id===query.toLowerCase())
                    providers.push(action);
            }
            if(!found.length && !providers.length) {
                const web=Search.webResult(query);
                if(web) providers.push(web);
            }
        }
        appRows=found;
        providerRows=providers.slice(0,5);
        if(LauncherModel.selected>=selectionCount) LauncherModel.selected=0;
    }
    function chooseMode(mode) {
        LauncherModel.gridMode=mode;
        LauncherModel.setQuery("");
        rebuild();focusInput();
    }
    function moveSelection(delta) {
        if(!selectionCount) return;
        LauncherModel.selected=(LauncherModel.selected+delta+selectionCount)%selectionCount;
        LauncherModel.confirmId="";
        const appIndex=LauncherModel.selected-providerRows.length;
        if(appIndex>=0 && appIndex<appRows.length) appGrid.positionViewAtIndex(appIndex,GridView.Contain);
    }
    function selectedRow() {
        const index=LauncherModel.selected;
        if(index<providerRows.length) return providerRows[index];
        if(index<providerRows.length+appRows.length) return appRows[index-providerRows.length];
        return quickActions[index-providerRows.length-appRows.length];
    }
    function activateSelection() {LauncherModel.activate(selectedRow());}
    function favoriteSelection() {
        const row=selectedRow();
        if(!row || row.kind!=="application") return false;
        LauncherModel.toggleFavorite(row.id);
        return true;
    }
    function openFavoriteMenu(row,item,x,y) {
        favoriteEntry=row;
        const point=item.mapToItem(card,x,y);
        favoriteMenu.x=Math.min(card.width-favoriteMenu.width-8,Math.max(8,point.x));
        favoriteMenu.y=Math.min(card.height-favoriteMenu.height-8,Math.max(8,point.y));
        favoriteMenu.open();
        Qt.callLater(function(){if(favoriteMenu.opened)favoriteMenu.contentItem.forceActiveFocus();});
    }
    function selectedFavoriteMenu() {
        const index=LauncherModel.selected-providerRows.length;
        if(index<0 || index>=appRows.length) return false;
        appGrid.positionViewAtIndex(index,GridView.Contain);
        Qt.callLater(function(){
            const tile=appGrid.itemAtIndex(index);
            if(tile)card.openFavoriteMenu(appRows[index],tile,tile.width/2,tile.height/2);
        });
        return true;
    }
    function moveFavoriteSelection(delta) {
        if(!canReorder)return false;
        const index=LauncherModel.selected-providerRows.length,target=index+delta;
        if(index<0 || target<0 || target>=appRows.length)return false;
        LauncherModel.moveFavorite(appRows[index].id,appRows[target].id);
        LauncherModel.selected=target+providerRows.length;
        return true;
    }
    function endFavoriteDrag(commit) {
        const source=draggedFavorite;
        const target=favoriteDropIndex>=0 && favoriteDropIndex<appRows.length ? appRows[favoriteDropIndex].id : "";
        favoriteDragging=false;draggedFavorite="";favoriteDropIndex=-1;
        if(commit && source && target && source!==target)Qt.callLater(function(){LauncherModel.moveFavorite(source,target);});
    }
    function geometry() {
        function box(item) {const point=item.mapToItem(card,0,0);return {x:point.x,y:point.y,width:item.width,height:item.height};}
        const apps=[];
        for(let index=0;index<appGrid.count;index++) {
            const tile=appGrid.itemAtIndex(index);
            if(tile && tile.y>=appGrid.contentY && tile.y+tile.height<=appGrid.contentY+appGrid.height)
                apps.push({id:appRows[index].id,box:box(tile)});
        }
        const modes=[];
        for(let i=0;i<modeTabs.count;i++)modes.push({id:["all","favorites","recent"][i],box:box(modeTabs.itemAt(i))});
        return {width:width,height:height,mode:LauncherModel.gridMode,appCount:appRows.length,providers:providerRows.map(function(row){return {kind:row.kind,name:row.name};}),columns:columns,search:box(field),apps:apps,actions:box(actionStrip),modes:modes,favorites:SettingsStore.pinnedIds,favoriteMenu:favoriteMenu.opened,favoriteAction:favoriteMenu.opened ? box(favoriteMenu.contentItem) : null};
    }
    Connections {
        target: LauncherModel
        function onQueryChanged() {card.rebuild();}
        function onApplicationsChanged() {card.rebuild();}
        function onRecentIdsChanged() {card.rebuild();}
        function onGridModeChanged() {card.rebuild();}
        function onWindowEntriesChanged(){if(card.searching)card.rebuild()}
    }
    Connections {target:SettingsStore;function onPinnedIdsChanged(){card.rebuild();}function onSearchWindowsChanged(){card.rebuild()}}
    Connections {target:DesktopTools;function onHistoryChanged(){if(card.searching)card.rebuild()}}
    Component.onCompleted: rebuild()
    Keys.onEscapePressed: {closeRequested();}
    MouseArea {anchors.fill:parent;onClicked:card.focusInput();}
    Column {
        id:header
        anchors {left:parent.left;right:parent.right;top:parent.top;leftMargin:22;rightMargin:22;topMargin:18}
        spacing:10
        Item {
            width:parent.width;height:54
            Canvas {
                x:2;y:17;width:22;height:22
                property color stroke:Theme.settingsMuted
                onStrokeChanged:requestPaint()
                onPaint:{const c=getContext("2d");c.reset();c.strokeStyle=stroke;c.lineWidth=1.7;c.beginPath();c.arc(9,9,6.5,0,Math.PI*2);c.moveTo(14,14);c.lineTo(20,20);c.stroke();}
            }
            TextInput {
                id:field
                objectName:"launcherSearchInput"
                x:36;width:parent.width-36;height:parent.height
                verticalAlignment:TextInput.AlignVCenter
                color:Theme.settingsText;selectionColor:Theme.settingsSelected;selectedTextColor:Theme.settingsText
                font.family:Theme.settingsFontFamily;font.pixelSize:Math.max(22,Theme.settingsFontSize+8)
                focus:true;clip:true;selectByMouse:true
                text:LauncherModel.query
                Accessible.name:"Search apps, settings, calculations and the web"
                onTextChanged:if(text!==LauncherModel.query)LauncherModel.setQuery(text)
                Keys.onPressed:function(event) {
                    const alt=(event.modifiers&Qt.AltModifier)!==0;
                    const shift=(event.modifiers&Qt.ShiftModifier)!==0;
                    if(event.key===Qt.Key_Escape){card.closeRequested();event.accepted=true;}
                    else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter){card.activateSelection();event.accepted=true;}
                    else if(alt && shift && (event.key===Qt.Key_H || event.key===Qt.Key_L)){event.accepted=card.moveFavoriteSelection(event.key===Qt.Key_H ? -1 : 1);}
                    else if((event.modifiers&Qt.ControlModifier)!==0 && event.key===Qt.Key_D){event.accepted=card.favoriteSelection();}
                    else if(event.key===Qt.Key_Menu || (shift && event.key===Qt.Key_F10)){event.accepted=card.selectedFavoriteMenu();}
                    else if(event.key===Qt.Key_Tab || event.key===Qt.Key_Backtab){card.moveSelection(shift || event.key===Qt.Key_Backtab ? -1 : 1);event.accepted=true;}
                    else if(event.key===Qt.Key_Down || event.key===Qt.Key_Up){card.moveSelection(event.key===Qt.Key_Down ? card.columns : -card.columns);event.accepted=true;}
                    else if(alt && [Qt.Key_J,Qt.Key_K,Qt.Key_H,Qt.Key_L].indexOf(event.key)>=0){card.moveSelection(event.key===Qt.Key_J || event.key===Qt.Key_L ? 1 : -1);event.accepted=true;}
                    else if((event.modifiers&Qt.ControlModifier)!==0 && [Qt.Key_1,Qt.Key_2,Qt.Key_3].indexOf(event.key)>=0){card.chooseMode(["all","favorites","recent"][event.key-Qt.Key_1]);event.accepted=true;}
                }
                Text {
                    anchors.fill:parent;verticalAlignment:Text.AlignVCenter
                    visible:field.text==="";text:"Search anything";color:Theme.settingsMuted
                    font:field.font
                }
            }
        }
        Row {
            width:parent.width;height:30;spacing:4
            Repeater {
                id:modeTabs
                model:[{id:"all",label:"All apps"},{id:"favorites",label:"Favorites"},{id:"recent",label:"Recent"}]
                delegate:FlatButton {
                    required property var modelData
                    objectName:"spotlight-"+modelData.id
                    label:modelData.label;emphasized:LauncherModel.gridMode===modelData.id && !card.searching
                    onActivated:card.chooseMode(modelData.id)
                }
            }
        }
    }
    Column {
        id:providerList
        anchors {top:header.bottom;left:parent.left;right:parent.right;topMargin:8;leftMargin:18;rightMargin:18}
        spacing:2
        Repeater {
            model:card.providerRows
            delegate:MouseArea {
                id:provider
                required property int index
                required property var modelData
                width:providerList.width;height:48;hoverEnabled:true;cursorShape:Qt.PointingHandCursor
                Accessible.role:Accessible.Button;Accessible.name:modelData.name
                onClicked:{LauncherModel.selected=index;card.activateSelection();}
                Rectangle {anchors.fill:parent;radius:Theme.controlRadius;color:LauncherModel.selected===provider.index ? Theme.settingsSelected : provider.containsMouse ? Theme.settingsHover : "transparent";}
                Column {
                    anchors {left:parent.left;right:parent.right;verticalCenter:parent.verticalCenter;leftMargin:12;rightMargin:12}
                    spacing:2
                    Text {objectName:"spotlightProviderName-"+provider.index;width:parent.width;textFormat:Text.PlainText;text:provider.modelData.name;elide:Text.ElideRight;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:provider.modelData.kind==="calculation" ? Theme.settingsFontSize+6 : Theme.settingsFontSize;}
                    Text {objectName:"spotlightProviderDetail-"+provider.index;width:parent.width;textFormat:Text.PlainText;text:provider.modelData.detail || "Enter to select";elide:Text.ElideRight;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;}
                }
            }
        }
    }
    GridView {
        id:appGrid
        objectName:"spotlightAppGrid"
        anchors {top:providerList.bottom;bottom:footer.top;left:parent.left;right:parent.right;topMargin:8;bottomMargin:8;leftMargin:18;rightMargin:18}
        clip:true;boundsBehavior:Flickable.StopAtBounds
        model:card.appRows;cellWidth:width/card.columns;cellHeight:94
        currentIndex:LauncherModel.selected-card.providerRows.length
        Controls.ScrollBar.vertical:Controls.ScrollBar {policy:Controls.ScrollBar.AsNeeded}
        delegate:MouseArea {
            id:tile
            required property int index
            required property var modelData
            width:appGrid.cellWidth;height:appGrid.cellHeight
            acceptedButtons:Qt.LeftButton|Qt.RightButton
            hoverEnabled:true;cursorShape:card.canReorder ? Qt.OpenHandCursor : Qt.PointingHandCursor
            drag.target:card.canReorder ? favoriteGhost : null
            drag.axis:Drag.XAndYAxis
            drag.smoothed:false
            property bool dragged:false
            onPressed:function(event) {
                dragged=false;
                if(event.button===Qt.LeftButton && card.canReorder) {
                    const point=tile.mapToItem(card,0,0);
                    favoriteGhost.x=point.x;favoriteGhost.y=point.y;
                    favoriteGhost.width=width;favoriteGhost.height=height;
                    card.draggedFavorite=modelData.id;card.favoriteDropIndex=index;
                }
            }
            onPositionChanged: {
                if(drag.active && card.canReorder) {
                    dragged=true;card.favoriteDragging=true;
                    const point=favoriteGhost.mapToItem(appGrid,favoriteGhost.width/2,favoriteGhost.height/2);
                    card.favoriteDropIndex=appGrid.indexAt(point.x+appGrid.contentX,point.y+appGrid.contentY);
                }
            }
            onReleased: {
                if(dragged) {
                    const point=favoriteGhost.mapToItem(appGrid,favoriteGhost.width/2,favoriteGhost.height/2);
                    card.favoriteDropIndex=appGrid.indexAt(point.x+appGrid.contentX,point.y+appGrid.contentY);
                }
                card.endFavoriteDrag(dragged)
            }
            onCanceled:card.endFavoriteDrag(false)
            Accessible.role:Accessible.Button;Accessible.name:modelData.name
            Accessible.description:card.canReorder ? "Drag to reorder. Alt Shift H and L move the selected favorite." : "Open application"
            readonly property bool current:LauncherModel.selected===index+card.providerRows.length
            onClicked:function(event) {
                if(dragged){dragged=false;return;}
                LauncherModel.selected=index+card.providerRows.length;
                if(event.button===Qt.RightButton) {
                    card.openFavoriteMenu(modelData,tile,event.x,event.y);
                } else card.activateSelection();
            }
            Rectangle {anchors {fill:parent;margins:3} radius:Theme.controlRadius;color:card.favoriteDragging && card.favoriteDropIndex===tile.index ? Theme.settingsSelected : tile.current ? Theme.settingsSelected : tile.containsMouse ? Theme.settingsHover : "transparent";}
            opacity:card.favoriteDragging && card.draggedFavorite===modelData.id ? .35 : 1
            Image {
                id:appIcon
                anchors {top:parent.top;horizontalCenter:parent.horizontalCenter;topMargin:10}
                width:44;height:44;source:card.iconFor(tile.modelData.icon)
                fillMode:Image.PreserveAspectFit;asynchronous:true;cache:true;mipmap:true
                sourceSize.width:Math.round(44*Math.max(1,Screen.devicePixelRatio));sourceSize.height:Math.round(44*Math.max(1,Screen.devicePixelRatio))
            }
            Text {
                anchors.centerIn:appIcon
                visible:appIcon.source==="" || appIcon.status===Image.Error
                text:Launcher.monogram(tile.modelData.name);font.family:Theme.settingsFontFamily;font.pixelSize:28;color:Theme.settingsText
            }
            Text {
                anchors {top:appIcon.bottom;left:parent.left;right:parent.right;topMargin:6;leftMargin:6;rightMargin:6}
                height:30;maximumLineCount:2;wrapMode:Text.WordWrap;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter
                text:tile.modelData.name;textFormat:Text.PlainText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;color:Theme.settingsText
            }
        }
        Text {
            anchors.centerIn:parent;width:parent.width-24;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.WordWrap
            visible:card.appRows.length===0 && card.providerRows.length===0
            text:LauncherModel.indexPending ? "Finding your applications…" : LauncherModel.gridMode==="favorites" ? "Your favorites belong here.\nRight-click an app in All apps to add it." : LauncherModel.gridMode==="recent" ? "Apps you open here will appear in Recent." : "No applications available."
            color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
        }
    }
    Column {
        id:footer
        anchors {left:parent.left;right:parent.right;bottom:parent.bottom;leftMargin:18;rightMargin:18;bottomMargin:14}
        spacing:5
        Text {
            width:parent.width;visible:LauncherModel.notice!=="" || LauncherModel.confirmId!==""
            text:LauncherModel.confirmId!=="" ? "Select again to confirm · Escape to cancel" : LauncherModel.notice
            color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;horizontalAlignment:Text.AlignHCenter;elide:Text.ElideRight
        }
        Row {
            id:actionStrip
            anchors.horizontalCenter:parent.horizontalCenter
            spacing:8
            Repeater {
                model:card.quickActions
                delegate:MouseArea {
                    id:action
                    required property int index
                    required property var modelData
                    objectName:"spotlight-action-"+modelData.id
                    width:Math.min(82,(card.width-64)/5);height:62;hoverEnabled:true
                    enabled:!LauncherModel.actionBusy;opacity:enabled ? 1 : .5
                    cursorShape:enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    Accessible.role:Accessible.Button;Accessible.name:modelData.name
                    readonly property bool current:LauncherModel.selected===card.providerRows.length+card.appRows.length+index
                    onClicked:{LauncherModel.selected=card.providerRows.length+card.appRows.length+index;LauncherModel.activate(modelData);}
                    Rectangle {anchors.fill:parent;radius:Theme.controlRadius;color:action.current || LauncherModel.confirmId===action.modelData.id ? Theme.settingsSelected : action.containsMouse ? Theme.settingsHover : "transparent";}
                    Canvas {
                        id:actionIcon
                        anchors {top:parent.top;horizontalCenter:parent.horizontalCenter;topMargin:8}
                        width:26;height:26
                        property color ink:Theme.settingsText
                        onInkChanged:requestPaint()
                        onPaint: {
                            const c=getContext("2d"),id=action.modelData.id;c.reset();c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1.7;c.lineCap="round";c.lineJoin="round";c.beginPath();
                            if(id==="settings") {c.arc(13,13,7,0,Math.PI*2);c.moveTo(16,13);c.arc(13,13,3,0,Math.PI*2);for(let i=0;i<8;i++){const a=i*Math.PI/4;c.moveTo(13+9*Math.cos(a),13+9*Math.sin(a));c.lineTo(13+11*Math.cos(a),13+11*Math.sin(a));}}
                            else if(id==="lock") {c.rect(5,11,16,12);c.moveTo(8,11);c.lineTo(8,7);c.arc(13,7,5,Math.PI,0);c.lineTo(18,11);c.moveTo(13,16);c.lineTo(13,19);}
                            else if(id==="suspend") {c.arc(13,13,9,-Math.PI/2,Math.PI/2);c.bezierCurveTo(3,20,3,6,13,4);}
                            else if(id==="reboot") {c.arc(13,13,9,-Math.PI*.65,Math.PI*.9);c.moveTo(10,3);c.lineTo(15,5);c.lineTo(10,8);}
                            else {c.arc(13,14,9,-Math.PI*.35,Math.PI*1.35);c.moveTo(13,2);c.lineTo(13,13);}
                            c.stroke();
                        }
                    }
                    Text {anchors {left:parent.left;right:parent.right;bottom:parent.bottom;bottomMargin:5} text:action.modelData.name;horizontalAlignment:Text.AlignHCenter;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall;elide:Text.ElideRight;}
                }
            }
        }
        Text {width:parent.width;text:card.canReorder ? "Drag favorites to arrange · Alt Shift H/L to move · Enter to open" : "Tab to browse · Ctrl D favorite · Enter to open · Esc to close";horizontalAlignment:Text.AlignHCenter;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Math.max(10,Theme.settingsFontSizeSmall-1);}
    }
    Rectangle {
        id:favoriteGhost
        visible:card.favoriteDragging
        z:20
        radius:Theme.controlRadius
        color:Theme.settingsSelected
        opacity:.94
        Image {
            anchors.centerIn:parent
            width:44;height:44
            readonly property var row:card.appRows.find(function(item){return item.id===card.draggedFavorite})
            source:row ? card.iconFor(row.icon) : ""
            fillMode:Image.PreserveAspectFit
        }
    }
    Controls.Popup {
        id:favoriteMenu
        objectName:"spotlightFavoriteMenu"
        parent:card
        width:220;padding:6;focus:true;modal:false
        closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:Rectangle {color:Theme.settingsPopupSurface;radius:Theme.controlRadius;}
        onClosed:Qt.callLater(card.focusInput)
        contentItem:FlatButton {
            label:card.favoriteEntry && SettingsStore.pinnedIds.indexOf(card.favoriteEntry.id)>=0 ? "Remove from favorites" : "Add to favorites"
            onActivated:{if(card.favoriteEntry)LauncherModel.toggleFavorite(card.favoriteEntry.id);favoriteMenu.close();}
        }
    }
}
