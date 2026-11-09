import QtQuick
import QtTest
import "../../shell/components" as Components
import "../../shell/settings" as Settings
import "../../shell/services" as Services
import "../../shell/logic/settingsFocus.js" as Focus
import "../../shell/logic/settingsNav.js" as Nav

TestCase {
    id:test
    name:"SettingsInteraction"
    when:windowShown
    visible:true
    width:700;height:600
    Component {
        id:sliderFixture
        Flickable {
            width:400;height:180;contentWidth:width;contentHeight:900
            property real level:.25
            contentY:200
            Components.CompactSlider {
                objectName:"boundSlider"
                x:30;y:260;width:300
                value:parent.parent.level
                onMoved:function(next){parent.parent.level=next}
            }
        }
    }
    Component {
        id:sectionFixture
        Components.SettingsSection {
            width:560
            sectionId:"test.opacity"
            title:"Surfaces"
            controlIds:["panelOpacity"]
            Components.CompactSlider {property string controlId:"panelOpacity";width:200}
        }
    }
    Component {id:toggleFixture;Components.SettingsToggle {width:300;label:"Example";onToggled:function(next){checked=next}}}
    Component {id:choiceFixture;Components.ChoiceBox {x:20;y:20;choices:[{label:"First",value:"a"},{label:"Second",value:"b"},{label:"Third",value:"c"}];selectedValue:"a"}}
    function test_section_animates_clipped_height_and_has_clear_hierarchy() {
        const saved=Services.SettingsStore.snapshot()
        Services.SettingsStore.setReducedMotion(false)
        const section=sectionFixture.createObject(test)
        section.setExpanded(true)
        tryCompare(section,"disclosureHeight",section.expandedHeight)
        const full=section.disclosureHeight
        verify(full>0)
        compare(section.contentItem.x,16)
        compare(section.contentItem.width,section.width-16)
        const heading=findChild(section,"sectionHeading")
        compare(heading.x,0);compare(heading.font.weight,Font.Bold)
        section.setExpanded(false)
        verify(!section.contentItem.enabled,"Closing controls must stop receiving input immediately")
        wait(35)
        verify(section.disclosureHeight>0 && section.disclosureHeight<full)
        tryCompare(section,"disclosureHeight",0)
        section.setExpanded(true)
        wait(35)
        verify(section.disclosureHeight>0 && section.disclosureHeight<full)
        tryCompare(section,"disclosureHeight",full)
        Services.SettingsStore.setReducedMotion(true)
        section.setExpanded(false)
        tryCompare(section,"disclosureHeight",0)
        section.destroy();Services.SettingsStore.applyDocument(saved)
    }
    function test_toggle_animates_both_directions_and_reduced_motion_is_instant() {
        const saved=Services.SettingsStore.snapshot()
        Services.SettingsStore.setReducedMotion(false)
        const toggle=toggleFixture.createObject(test)
        const thumb=findChild(toggle,"toggleThumb")
        compare(thumb.x,3)
        verify(findChild(toggle,"toggleLabel").font.weight<Font.Bold)
        mouseClick(toggle)
        verify(toggle.checked)
        wait(35);verify(thumb.x>3 && thumb.x<17)
        tryCompare(thumb,"x",17)
        mouseClick(toggle)
        wait(35);verify(thumb.x>3 && thumb.x<17)
        tryCompare(thumb,"x",3)
        Services.SettingsStore.setReducedMotion(true)
        mouseClick(toggle);tryCompare(thumb,"x",17)
        toggle.destroy();Services.SettingsStore.applyDocument(saved)
    }
    function test_dropdown_expands_and_retracts_without_scaling_text() {
        failOnWarning(/Cannot animate|Binding loop|TypeError|ReferenceError/)
        const saved=Services.SettingsStore.snapshot()
        Services.SettingsStore.setReducedMotion(false)
        const choice=choiceFixture.createObject(test)
        choice.popup.open()
        wait(35)
        verify(choice.popup.reveal>0 && choice.popup.reveal<1)
        verify(choice.popup.height<choice.popup.implicitHeight)
        compare(choice.popup.scale,1)
        tryCompare(choice.popup,"opened",true)
        choice.popup.close()
        wait(25)
        verify(choice.popup.visible)
        verify(choice.popup.reveal>0 && choice.popup.reveal<1)
        tryCompare(choice.popup,"visible",false)
        choice.popup.open();wait(25);choice.popup.close();wait(20);choice.popup.open()
        tryCompare(choice.popup,"opened",true)
        compare(choice.popup.reveal,1)
        choice.popup.close();tryCompare(choice.popup,"visible",false)
        Services.SettingsStore.setReducedMotion(true)
        choice.popup.open();tryCompare(choice.popup,"opened",true);compare(choice.popup.reveal,1)
        choice.popup.close();tryCompare(choice.popup,"visible",false)
        choice.destroy();Services.SettingsStore.applyDocument(saved)
    }
    function test_settings_content_cannot_be_drag_scrolled_but_wheel_and_keyboard_work() {
        const saved=Services.SettingsStore.snapshot()
        Services.SettingsStore.setReducedMotion(true)
        Services.SettingsStore.setSettingsCategory("bar")
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test,{width:640,height:440,visible:true,placementReady:true})
        window.setAllSectionsExpanded(true)
        const scroller=findChild(window,"settingsScroller")
        verify(!scroller.interactive)
        verify(!findChild(window,"settingsNavigationScroller").interactive)
        tryVerify(function(){return scroller.contentHeight>scroller.height+300})
        wait(50)
        scroller.contentY=100
        mousePress(scroller,2,100,Qt.LeftButton)
        mouseMove(scroller,2,25,35)
        mouseRelease(scroller,2,25,Qt.LeftButton)
        compare(scroller.contentY,100)
        mouseWheel(scroller,2,100,0,-120)
        tryVerify(function(){return scroller.contentY>100})
        const before=scroller.contentY
        scroller.forceActiveFocus();keyClick(Qt.Key_PageDown)
        verify(scroller.contentY>before)
        scroller.contentY=scroller.contentHeight-scroller.height
        window.setAllSectionsExpanded(false)
        tryVerify(function(){return scroller.contentY<=Math.max(0,scroller.contentHeight-scroller.height)})
        window.destroy();Services.SettingsStore.applyDocument(saved)
    }
    function test_slider_drag_keeps_page_still_and_binding_live() {
        const fixture=sliderFixture.createObject(test)
        verify(fixture!==null)
        const slider=findChild(fixture,"boundSlider")
        compare(slider.value,.25)
        mousePress(slider,75,14,Qt.LeftButton)
        verify(slider.adjusting)
        mouseMove(slider,270,65,30)
        compare(fixture.contentY,200)
        verify(fixture.level>.8)
        wait(150)
        compare(findChild(slider,"sliderTrack").height,6)
        mouseRelease(slider,270,65,Qt.LeftButton)
        compare(slider.adjusting,false)
        fixture.level=.1
        tryCompare(slider,"value",.1)
        compare(slider.displayValue,.1)
        fixture.destroy()
    }
    function test_search_expands_without_overwriting_section_preference() {
        const section=sectionFixture.createObject(test)
        section.setExpanded(false)
        compare(section.expanded,false)
        compare(section.effectiveExpanded,false)
        section.searchQuery="opacity"
        compare(section.matchesSearch,true)
        compare(section.effectiveExpanded,true)
        compare(section.expanded,false)
        section.searchQuery=""
        compare(section.effectiveExpanded,false)
        section.setExpanded(true)
        compare(section.expanded,true)
        section.destroy()
    }
    function test_navigation_reveals_the_control_inside_a_collapsed_section() {
        const section=sectionFixture.createObject(test)
        section.setExpanded(false)
        const control=Focus.findControl(section,"panelOpacity")
        verify(control!==null)
        Focus.revealAncestors(control)
        compare(section.expanded,true)
        verify(Focus.focusFirst(control))
        section.destroy()
    }
    function test_resize_frame_follows_visible_surface() {
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test,{width:1000,height:700})
        verify(window!==null)
        const frame=window.frameGeometry()
        compare(frame.x,32);compare(frame.y,32)
        compare(frame.width,936);compare(frame.height,636)
        compare(frame.resizeInset,0);compare(frame.resizeBand,7)
        verify(window.mask.item!==null)
        window.destroy()
    }
    function test_settings_first_buffer_contains_ui_before_placement_reply() {
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test,{visible:true,placementReady:false})
        verify(window!==null)
        compare(findChild(window,"settingsContent").opacity,1)
        verify(window.activePage()!==null)
        compare(window.presentationDiagnostics().contentOpacity,1)
        verify(window.presentationDiagnostics().pageReady)
        compare(window.placementReady,false)
        window.destroy()
    }
    function test_one_slider_gesture_is_one_undo_step() {
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test)
        const before=Services.SettingsStore.fontSize
        const next=before<16 ? before+1 : before-1
        const last=next<16 ? next+1 : next-1
        window.beginAppearanceGesture()
        window.commit({fontSize:next})
        window.commit({fontSize:last})
        window.endAppearanceGesture()
        compare(window.history.past.length,1)
        compare(Services.SettingsStore.fontSize,last)
        window.undo()
        compare(Services.SettingsStore.fontSize,before)
        window.destroy()
    }
    function test_collapse_expand_on_every_page_data() {
        return Nav.categories().map(function(category){return {tag:category.id,category:category.id}})
    }
    function test_collapse_expand_on_every_page(data) {
        const saved=Services.SettingsStore.snapshot()
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        Services.SettingsStore.setSettingsCategory(data.category)
        const window=component.createObject(test,{width:1000,height:700,visible:true})
        verify(window!==null)
        const collapse=findChild(window,"collapseAllSections"),expand=findChild(window,"expandAllSections")
        verify(collapse!==null);verify(expand!==null)
        verify(collapse.visible);verify(expand.visible)
        const search=findChild(window,"settingsSearch")
        verify(collapse.mapToItem(window,0,0).y>search.mapToItem(window,0,0).y)
        const ids=Focus.sectionIds(window.activePage())
        verify(ids.length>0,"Every Settings page must expose its sections: "+data.category)
        Services.SettingsStore.setSettingsSection("test.unrelated",true)
        collapse.activated()
        tryVerify(function(){const states=JSON.parse(Services.SettingsStore.settingsSectionsJson);return ids.every(function(id){return states[id]===false})})
        compare(JSON.parse(Services.SettingsStore.settingsSectionsJson)["test.unrelated"],true)
        // Revisit the page: the disclosure choice is remembered.
        Services.SettingsStore.setSettingsCategory(data.category==="appearance" ? "bar" : "appearance")
        Services.SettingsStore.setSettingsCategory(data.category)
        const states=JSON.parse(Services.SettingsStore.settingsSectionsJson)
        for(const id of ids)compare(states[id],false)
        expand.activated()
        tryVerify(function(){const current=JSON.parse(Services.SettingsStore.settingsSectionsJson);return ids.every(function(id){return current[id]===true})})
        window.destroy()
        Services.SettingsStore.applyDocument(saved)
    }
    function test_collapse_during_search_clears_filter_and_collapses() {
        const saved=Services.SettingsStore.snapshot()
        const component=Qt.createComponent("../../shell/settings/SettingsWindow.qml")
        compare(component.status,Component.Ready,component.errorString())
        const window=component.createObject(test,{width:1000,height:700,visible:true})
        const search=findChild(window,"settingsSearch")
        search.text="opacity"
        compare(Services.SettingsStore.settingsWindowCategory,"appearance")
        findChild(window,"collapseAllSections").activated()
        tryCompare(search,"text","")
        tryVerify(function(){return window.uiGeometry().sections.every(function(section){return !section.effectiveExpanded})})
        window.destroy()
        Services.SettingsStore.applyDocument(saved)
    }
}
