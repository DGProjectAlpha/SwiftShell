import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/themes" as Themes
TestCase {
    id:test
    name:"ConsistentColorPicker"
    when:windowShown
    visible:true
    width:640;height:480
    property var picker:null
    property int emissions:0
    property string chosen:""
    function init() {
        const component=Qt.createComponent("../../shell/settings/ColorPicker.qml")
        compare(component.status,Component.Ready,component.errorString())
        picker=component.createObject(test,{selectedColor:Qt.rgba(.1,.2,.3,.4),field:"manualText"})
        emissions=0;chosen=""
        picker.colorChosen.connect(function(field,value){compare(field,"manualText");emissions++;chosen=value})
    }
    function cleanup() { picker.close();picker.destroy();picker=null }
    function test_drag_drafts_without_saving_cancel_preserves_original() {
        picker.open();tryCompare(picker,"opened",true)
        const before=picker.selectedColor
        const popup=findChild(picker,"colorPickerPopup")
        verify(popup.parent !== null, "Color picker must attach to its window overlay")
        compare(popup.parent.width,640)
        const square=findChild(picker,"colorSpectrum")
        mousePress(square,20,20,Qt.LeftButton)
        mouseMove(square,square.width-12,square.height-12,20)
        mouseRelease(square,square.width-12,square.height-12,Qt.LeftButton)
        verify(picker.colorHex(picker.draftColor)!==picker.colorHex(before))
        compare(emissions,0);compare(picker.selectedColor,before)
        picker.reject();tryCompare(picker,"opened",false)
        compare(emissions,0);compare(picker.selectedColor,before)
    }
    function test_accept_valid_hex_once() {
        picker.open();tryCompare(picker,"opened",true)
        const input=findChild(picker,"colorHex")
        input.text="#abcdef"
        picker.accept()
        compare(chosen,"#abcdef");compare(emissions,1)
        tryCompare(picker,"opened",false)
    }
    function test_invalid_hex_does_not_commit_or_close() {
        picker.open();tryCompare(picker,"opened",true)
        findChild(picker,"colorHex").text="not-a-color"
        picker.accept()
        compare(emissions,0);compare(picker.opened,true);compare(picker.invalidHex,true)
    }
    function test_escape_closes_without_commit() {
        picker.open();tryCompare(picker,"opened",true)
        keyClick(Qt.Key_Escape)
        tryCompare(picker,"opened",false)
        compare(emissions,0)
    }
    function test_theme_matches_settings_without_native_window() {
        picker.open();tryCompare(picker,"opened",true)
        const popup=findChild(picker,"colorPickerPopup")
        const old=Services.SettingsStore.appearanceMode
        Services.SettingsStore.setAppearanceMode("light")
        compare(popup.background.color,Themes.Theme.settingsPopupSurface)
        Services.SettingsStore.setAppearanceMode("dark")
        compare(popup.background.color,Themes.Theme.settingsPopupSurface)
        Services.SettingsStore.setAppearanceMode(old)
    }
    function test_keyboard_edits_draft_and_opaque_hex_is_valid() {
        picker.open();tryCompare(picker,"opened",true)
        const previous=picker.brightness
        keyClick(Qt.Key_J,Qt.AltModifier)
        verify(picker.brightness<previous)
        picker.accept()
        verify(/^#[0-9a-f]{6}$/.test(chosen))
        compare(emissions,1)
    }
}
