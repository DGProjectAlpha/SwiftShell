import QtQuick
import QtTest
import "../../shell/components" as Components
import "../../shell/settings" as Settings
import "../../shell/services" as Services
import "../../shell/logic/settingsFocus.js" as Focus

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
}
