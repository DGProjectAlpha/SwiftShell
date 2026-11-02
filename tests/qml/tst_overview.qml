import QtQuick
import QtTest
import Quickshell.Hyprland
import "../../shell/services" as Services
TestCase {
    id:test
    name:"WorkspaceOverview"
    when:windowShown
    visible:true;width:640;height:480
    property var card:null
    property var oldWindows:[]
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/);
        oldWindows=Hyprland.toplevels.values;
        Hyprland.toplevels.values=[
            {address:"0x1",title:"First",activated:true,wayland:null,lastIpcObject:{at:[117,-53],size:[1270,1400],mapped:true,workspace:{address:"1",type:"normal"}}},
            {address:"0x2",title:"Second",activated:false,wayland:null,lastIpcObject:{at:[1397,-53],size:[1270,1400],mapped:true,workspace:{address:"1",type:"normal"}}},
            {address:"0x3",title:"Gaming",activated:false,wayland:null,lastIpcObject:{at:[117,-53],size:[2550,1400],mapped:true,workspace:{address:"gaming",type:"normal"}}}
        ];
        const component=Qt.createComponent("../../shell/overview/OverviewWorkspace.qml");
        compare(component.status,Component.Ready,component.errorString());
        card=component.createObject(test,{width:512,height:318,monitor:{x:112,y:-88,width:2560,height:1440,scale:1},workspace:{key:"1",name:"1",active:true}});
        verify(card!==null);wait(1);
    }
    function cleanup(){card.destroy();card=null;Hyprland.toplevels.values=oldWindows;}
    function tiles() {
        const items=[]
        const children=card.desktop.children
        for(let i=0;i<children.length;i++) {
            if(children[i].objectName==="overviewWindowTile")items.push(children[i])
        }
        return items
    }
    function test_real_tiling_preserved() {
        const items=tiles();compare(items.length,2);
        compare(items[0].x,1);compare(items[0].y,7);compare(items[0].width,254);compare(items[0].height,280);
        compare(items[1].x,257);compare(items[1].width,254);
        compare(items[0].previewReady,false); // No preview is invented for a missing protocol handle.
    }
    function test_named_and_empty_workspaces() {
        card.workspace={key:"gaming",name:"gaming",active:false};
        tryCompare(card,"windows",Services.OverviewService.windows.filter(function(w){return w.workspace==="gaming"}));
        compare(tiles().length,1);
        card.workspace={key:"2",name:"2",active:false};
        tryVerify(function(){return tiles().length===0});
    }
    function test_window_close_updates_live_grid() {
        Hyprland.toplevels.values=[];
        tryVerify(function(){return tiles().length===0});
    }
}
