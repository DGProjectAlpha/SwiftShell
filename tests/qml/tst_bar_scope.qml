import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/logic/settings.js" as Settings
import "../../shell/logic/bar.js" as Bar

TestCase {
    id:test
    name:"BarSettingsScope"
    when:windowShown
    visible:true;width:800;height:1200
    property var page:null
    property var saved:null
    property var monitors:null
    property var choices:null
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved=Services.SettingsStore.snapshot()
        monitors=Services.HyprlandModel.monitorSnapshot
        choices=Services.HyprlandModel.monitorChoices
        Services.SettingsStore.applyDocument(Settings.validateSettings({}).settings)
        Services.HyprlandModel.monitorSnapshot=[{name:"DP-1",focused:true},{name:"HDMI-A-1",focused:false}]
        Services.HyprlandModel.monitorChoices=[{name:"DP-1",label:"Main · DP-1"},{name:"HDMI-A-1",label:"Second · HDMI-A-1"}]
        const component=Qt.createComponent("../../shell/settings/BarPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        page=component.createObject(test,{width:560})
        verify(page!==null)
    }
    function cleanup() {
        if(page)page.destroy();page=null
        Services.SettingsStore.applyDocument(saved)
        Services.HyprlandModel.monitorSnapshot=monitors
        Services.HyprlandModel.monitorChoices=choices
    }
    function choose(output) {findChild(page,"barModulesOutput").chosen(output);compare(page.layoutOutput,output)}
    function layout(output) {return Services.SettingsStore.layoutForOutput(output)}
    function state(output) {
        return JSON.stringify({layout:layout(output),hidden:Services.SettingsStore.hiddenForOutput(output),surface:Bar.surfaceForOutput(Services.SettingsStore.barSurfaceMode,Services.SettingsStore.barSurfaceColor,Services.SettingsStore.barSurfaceOpacity,Services.SettingsStore.barSurfaceOutputsJson,output,false)})
    }
    function test_one_selector_scopes_size_and_every_behavior_control() {
        choose("HDMI-A-1")
        const other=state("DP-1"),globalHeight=Services.SettingsStore.barHeight
        const sizeSlider=findChild(page,"barSizeSlider")
        mouseClick(sizeSlider,sizeSlider.width*Bar.unitFromSize(42),sizeSlider.height/2)
        compare(page.selectedSize,42);compare(layout("HDMI-A-1").height,42)
        compare(Services.SettingsStore.barHeight,globalHeight)
        findChild(page,"barEdgeChoice").chosen("bottom")
        findChild(page,"barReserveSpace").toggled(false)
        findChild(page,"barClock24").toggled(false)
        findChild(page,"barClockSeconds").toggled(true)
        findChild(page,"barClockDate").toggled(true)
        findChild(page,"barDateFormat").chosen("iso")
        findChild(page,"barSearchLabel").toggled(false)
        findChild(page,"barFullscreenPeek").toggled(true)
        findChild(page,"barSurfaceStyle").chosen("solid")
        findChild(page,"barSurfaceOpacity").moved(.43)
        findChild(page,"barModuleOrderList").visibilityToggled("search")
        const current=layout("HDMI-A-1")
        compare(current.edge,"bottom");compare(current.reserveSpace,false)
        compare(current.use24Hour,false);compare(current.showSeconds,true)
        compare(current.showDate,true);compare(current.dateFormat,"iso")
        compare(current.searchLabel,false);compare(current.fullscreenPeek,true)
        compare(page.selectedSurface.opacity,.43)
        verify(Services.SettingsStore.hiddenForOutput("HDMI-A-1").indexOf("search")>=0)
        compare(state("DP-1"),other)
        // Store serialization/restoration must preserve exactly what the controls saved.
        const snapshot=JSON.parse(Settings.serializeSettings(Services.SettingsStore.snapshot()))
        Services.SettingsStore.applyDocument(Settings.validateSettings({}).settings)
        Services.SettingsStore.applyDocument(snapshot)
        compare(layout("HDMI-A-1").height,42);compare(state("DP-1"),other)
    }
    function test_all_displays_overwrites_only_edited_layout_fields() {
        Services.SettingsStore.patchBarOutput("DP-1",{height:44,scale:1.25,edge:"right",showSeconds:true})
        Services.SettingsStore.patchBarOutput("HDMI-A-1",{height:22,scale:.75,edge:"bottom",reserveSpace:false})
        choose("")
        findChild(page,"barSizeSlider").moved(Bar.unitFromSize(36))
        for(const output of ["DP-1","HDMI-A-1","future-output"]) {
            compare(layout(output).height,36);compare(layout(output).scale,1)
        }
        compare(layout("DP-1").edge,"right");compare(layout("DP-1").showSeconds,true)
        compare(layout("HDMI-A-1").edge,"bottom");compare(layout("HDMI-A-1").reserveSpace,false)
        findChild(page,"barClockSeconds").toggled(false)
        compare(layout("DP-1").showSeconds,false);compare(layout("HDMI-A-1").showSeconds,false)
        choose("DP-1")
        findChild(page,"barSizeSlider").moved(Bar.unitFromSize(24))
        compare(layout("DP-1").height,24);compare(layout("HDMI-A-1").height,36)
    }
    function test_all_background_and_widgets_reach_custom_outputs() {
        Services.SettingsStore.setBarSurface("DP-1","frosted","#123456",.8)
        Services.SettingsStore.setHiddenForOutput("DP-1",["search"])
        choose("")
        findChild(page,"barSurfaceStyle").chosen("solid")
        compare(JSON.parse(Services.SettingsStore.barSurfaceOutputsJson)["DP-1"].mode,"solid")
        compare(JSON.parse(Services.SettingsStore.barSurfaceOutputsJson)["DP-1"].color,"#123456")
        choose("DP-1");compare(page.selectedSurface.mode,"solid")
        choose("")
        findChild(page,"barModuleOrderList").visibilityToggled("clock")
        for(const output of ["DP-1","HDMI-A-1"])verify(Services.SettingsStore.hiddenForOutput(output).indexOf("clock")>=0)
        verify(Services.SettingsStore.hiddenForOutput("DP-1").indexOf("search")>=0)
        compare(Services.SettingsStore.hiddenForOutput("HDMI-A-1").indexOf("search"),-1)
        choose("DP-1")
        findChild(page,"barSizeSlider").moved(Bar.unitFromSize(44))
        findChild(page,"barUseSharedSettings").activated()
        compare(layout("DP-1").height,layout("").height)
        compare(page.layoutOutput,"DP-1")
    }
    function test_widget_title_visibility_has_one_control() {
        Services.SettingsStore.setShowFocusedTitle(false)
        choose("DP-1")
        verify(Services.SettingsStore.hiddenForOutput("DP-1").indexOf("title")>=0)
        findChild(page,"barModuleOrderList").visibilityToggled("title")
        verify(layout("DP-1").showFocusedTitle)
        compare(Services.SettingsStore.hiddenForOutput("DP-1").indexOf("title"),-1)
        compare(layout("HDMI-A-1").showFocusedTitle,false)
    }
    function test_all_widget_group_edit_preserves_other_groups() {
        Services.SettingsStore.patchBarOutput("DP-1",{sides:{clock:"left",search:"center"}})
        Services.SettingsStore.patchBarOutput("HDMI-A-1",{sides:{clock:"right",tray:"left"}})
        choose("")
        findChild(page,"barModuleOrderList").sideChosen("clock","center")
        compare(JSON.parse(layout("DP-1").sides).clock,"center")
        compare(JSON.parse(layout("HDMI-A-1").sides).clock,"center")
        compare(JSON.parse(layout("DP-1").sides).search,"center")
        compare(JSON.parse(layout("HDMI-A-1").sides).tray,"left")
    }
    function test_clock_renderer_accepts_independent_output_preferences() {
        const component=Qt.createComponent("../../shell/bar/ClockModule.qml")
        compare(component.status,Component.Ready,component.errorString())
        const first=component.createObject(test,{use24Hour:true,showSeconds:false,showDate:false})
        const second=component.createObject(test,{use24Hour:false,showSeconds:true,showDate:true,dateFormat:"iso"})
        verify(first!==null);verify(second!==null)
        verify(first.labelText!==second.labelText)
        first.showSeconds=true;compare(second.showSeconds,true)
        first.showDate=true;first.dateFormat="weekday";compare(second.dateFormat,"iso")
        first.destroy();second.destroy()
    }
    function test_scope_stays_selected_on_focus_change_and_disconnect() {
        choose("HDMI-A-1")
        Services.HyprlandModel.monitorSnapshot=[{name:"DP-1",focused:true}]
        Services.HyprlandModel.monitorChoices=[{name:"DP-1",label:"Main · DP-1"}]
        compare(page.layoutOutput,"HDMI-A-1")
        verify(page.scopeLabel.indexOf("disconnected")>=0)
        findChild(page,"barSizeSlider").moved(Bar.unitFromSize(32))
        compare(layout("HDMI-A-1").height,32);compare(layout("DP-1").height,28)
    }
}
