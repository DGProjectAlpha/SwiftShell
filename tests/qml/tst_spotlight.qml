import QtQuick
import QtTest
import Quickshell
import "../../shell/services" as Services
TestCase {
    id:test
    name:"SpotlightGrid"
    when:windowShown
    visible:true;width:680;height:560
    property var card:null
    property var oldApps:[]
    property var oldPins:[]
    property string oldDefaultMode:"all"
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/);
        oldApps=Services.LauncherModel.applications;
        oldPins=Services.SettingsStore.pinnedIds.slice();
        oldDefaultMode=Services.SettingsStore.launcherDefaultMode;
        const apps=[];
        for(let i=0;i<35;i++)apps.push({id:"app"+i+".desktop",name:"Application "+i,icon:""});
        Services.LauncherModel.applications=apps;
        Services.LauncherModel.query="";
        Services.LauncherModel.gridMode="all";
        Services.LauncherModel.selected=0;
        Services.SettingsStore.setPinnedIds([]);
        const component=Qt.createComponent("../../shell/launcher/LauncherCard.qml");
        compare(component.status,Component.Ready,component.errorString());
        card=component.createObject(test,{width:680,height:560});
        verify(card!==null);
        wait(1);
    }
    function cleanup() {
        card.destroy();card=null;
        Services.LauncherModel.query="";
        Services.LauncherModel.applications=oldApps;
        Services.SettingsStore.setPinnedIds(oldPins);
        Services.SettingsStore.setLauncherDefaultMode(oldDefaultMode);
    }
    function test_favorites_drag_and_keyboard_order_are_persisted() {
        Services.SettingsStore.setPinnedIds(["app0.desktop","app1.desktop","missing.desktop","app2.desktop"]);
        Services.LauncherModel.gridMode="favorites";
        const grid=findChild(card,"spotlightAppGrid");
        tryCompare(grid,"count",3);
        const first=grid.itemAtIndex(0);
        verify(first!==null);
        mousePress(first,first.width/2,40,Qt.LeftButton);
        mouseMove(first,first.width*1.3,40,20);
        mouseMove(first,first.width*2.5,40,20);
        compare(Services.SettingsStore.pinnedIds[0],"app0.desktop");
        mouseRelease(first,first.width*2.5,40,Qt.LeftButton);
        tryCompare(Services.SettingsStore,"pinnedIds",["app1.desktop","missing.desktop","app2.desktop","app0.desktop"]);
        compare(Services.LauncherModel.open,false);
        Services.LauncherModel.selected=2;
        verify(card.moveFavoriteSelection(-1));
        compare(Services.SettingsStore.pinnedIds.join(","),"app1.desktop,missing.desktop,app0.desktop,app2.desktop");
    }
    function test_favorite_icons_have_no_star_badge() {
        Services.SettingsStore.setPinnedIds(["app0.desktop"]);
        card.chooseMode("favorites");
        const grid=findChild(card,"spotlightAppGrid");
        tryCompare(grid,"count",1);
        const tile=grid.itemAtIndex(0);
        verify(tile!==null);
        function check(item) {
            if(item.text!==undefined)verify(item.text!=="★");
            for(let i=0;i<item.children.length;i++)check(item.children[i]);
        }
        check(tile);
        compare(Services.SettingsStore.pinnedIds[0],"app0.desktop");
    }
    function test_all_apps_scroll_and_use_real_grid() {
        compare(card.appRows.length,35);
        const grid=findChild(card,"spotlightAppGrid");
        verify(grid.cellHeight>70);verify(card.columns>=5);
        verify(grid.contentHeight>grid.height);
        card.moveSelection(20);
        compare(Services.LauncherModel.selected,20);
        verify(grid.contentY>0);
    }
    function test_right_click_favorite_and_view_switch() {
        const grid=findChild(card,"spotlightAppGrid");
        const tile=grid.itemAtIndex(0);
        verify(tile!==null);
        mouseClick(tile,20,20,Qt.RightButton);
        const popup=findChild(card,"spotlightFavoriteMenu");
        tryCompare(popup,"opened",true);
        popup.contentItem.activated();
        tryCompare(popup,"opened",false);
        compare(Services.SettingsStore.pinnedIds.length,1);
        card.chooseMode("favorites");
        compare(card.appRows.length,1);
        compare(card.appRows[0].id,Services.SettingsStore.pinnedIds[0]);
        Services.LauncherModel.toggleFavorite(card.appRows[0].id);
        compare(card.appRows.length,0);
    }
    function test_keyboard_favorite_and_context_menu() {
        card.focusInput();
        keyClick(Qt.Key_D,Qt.ControlModifier);
        compare(Services.SettingsStore.pinnedIds.length,1);
        keyClick(Qt.Key_F10,Qt.ShiftModifier);
        const popup=findChild(card,"spotlightFavoriteMenu");
        tryCompare(popup,"opened",true);
        tryVerify(function(){return popup.contentItem.activeFocus;});
        keyClick(Qt.Key_Return);
        tryCompare(popup,"opened",false);
        compare(Services.SettingsStore.pinnedIds.length,0);
    }
    function test_short_app_prefix_takes_selection_before_settings() {
        Services.LauncherModel.applications=[
            {id:"discord.desktop",name:"Discord",icon:""},
            {id:"disk.desktop",name:"Disk Usage",icon:""}
        ];
        card.focusInput();
        keyClick(Qt.Key_D);
        keyClick(Qt.Key_I);
        keyClick(Qt.Key_S);
        compare(Services.LauncherModel.query,"dis");
        compare(card.appRows[0].name,"Discord");
        compare(card.providerRows.length,0);
        compare(card.selectedRow().kind,"application");
        compare(card.selectedRow().id,"discord.desktop");
        // A settings-only query still reaches its exact control.
        Services.LauncherModel.setQuery("weather updates");
        compare(card.appRows.length,0);
        compare(card.selectedRow().kind,"setting-result");
        compare(card.selectedRow().controlId,"weatherRefresh");
    }
    function test_calculator_keeps_priority_over_matching_app() {
        Services.LauncherModel.applications=[{id:"calc.desktop",name:"2+2",icon:""}];
        Services.LauncherModel.setQuery("2+2");
        compare(card.appRows.length,1);
        compare(card.selectedRow().kind,"calculation");
    }
    function test_calculator_and_web_fallback_are_local_rows() {
        Services.LauncherModel.setQuery("2+2");
        compare(card.providerRows[0].kind,"calculation");
        compare(card.providerRows[0].name,"= 4");
        Services.LauncherModel.setQuery("a query with no application match");
        compare(card.providerRows.length,1);
        compare(card.providerRows[0].kind,"web");
        verify(card.providerRows[0].url.indexOf("https://www.google.com/search?q=")===0);
    }
    function test_saved_default_applies_each_open_without_overriding_manual_tabs() {
        const oldScreens=Quickshell.screens;
        const screen=Qt.createQmlObject('import QtQuick; QtObject { property string name: "spotlight-test" }',test);
        Quickshell.screens=[screen];
        try {
            verify(Services.SettingsStore.setLauncherDefaultMode("favorites"));
            Services.LauncherModel.openLauncher();
            compare(Services.LauncherModel.gridMode,"favorites");
            card.chooseMode("all");
            compare(Services.LauncherModel.gridMode,"all");
            compare(Services.SettingsStore.launcherDefaultMode,"favorites");
            Services.LauncherModel.closeLauncher();
            Services.LauncherModel.openLauncher();
            compare(Services.LauncherModel.gridMode,"favorites");
            verify(Services.SettingsStore.setLauncherDefaultMode("recent"));
            compare(Services.LauncherModel.gridMode,"favorites");
            Services.LauncherModel.closeLauncher();
            Services.LauncherModel.openLauncher();
            compare(Services.LauncherModel.gridMode,"recent");
            verify(!Services.SettingsStore.setLauncherDefaultMode("arbitrary"));
            compare(Services.SettingsStore.launcherDefaultMode,"recent");
        } finally {
            Services.LauncherModel.closeLauncher();
            Quickshell.screens=oldScreens;
            screen.destroy();
        }
    }
    function test_spotlight_settings_page_selects_persisted_opening_view() {
        const component=Qt.createComponent("../../shell/settings/SpotlightPage.qml");
        compare(component.status,Component.Ready,component.errorString());
        Services.SettingsStore.setLauncherDefaultMode("all");
        const page=component.createObject(test,{width:560});
        verify(page!==null);
        try {
            const choice=findChild(page,"spotlightDefaultModeChoice");
            verify(choice!==null);
            mouseClick(choice,choice.width/2,choice.height/2);
            tryCompare(choice.popup,"opened",true);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            tryCompare(choice.popup,"opened",false);
            compare(Services.SettingsStore.launcherDefaultMode,"favorites");
            compare(choice.selectedValue,"favorites");
            choice.chosen("recent");
            compare(Services.SettingsStore.snapshot().launcher.defaultMode,"recent");
            verify(findChild(page,"spotlightOpenButton")!==null);
        } finally { page.destroy(); }
    }
    function test_action_strip_and_destructive_confirmation_never_executes_first_click() {
        for(const id of ["settings","lock","suspend","logout","reboot","poweroff"])verify(findChild(card,"spotlight-action-"+id)!==null);
        Services.LauncherModel.runPower("reboot");
        compare(Services.LauncherModel.confirmId,"reboot");
        compare(Services.LauncherModel.actionBusy,false);
        Services.LauncherModel.confirmId="";
    }
    function test_all_session_actions_fit_the_narrow_launcher() {
        card.width=400
        waitForRendering(card)
        let right=0
        for(const id of ["settings","lock","suspend","logout","reboot","poweroff"]) {
            const action=findChild(card,"spotlight-action-"+id),position=action.mapToItem(card,0,0)
            verify(position.x>=0)
            verify(position.x>=right)
            verify(position.x+action.width<=card.width)
            right=position.x+action.width
        }
    }
    function test_provider_labels_render_literal_text() {
        card.providerRows=[{kind:"fixture",id:"literal",name:"<b>Literal query</b>",detail:"<i>Literal detail</i>"}]
        const name=findChild(card,"spotlightProviderName-0"),detail=findChild(card,"spotlightProviderDetail-0")
        verify(name!==null);verify(detail!==null)
        compare(name.textFormat,Text.PlainText);compare(detail.textFormat,Text.PlainText)
        compare(name.text,"<b>Literal query</b>")
    }

}
