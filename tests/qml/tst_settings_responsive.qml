import QtQuick
import QtTest
TestCase {
    id:test
    name:"ResponsiveSettings"
    when:windowShown
    visible:true
    width:1500;height:900
    function test_appearance_reflows_without_recreating_controls() {
        const component=Qt.createComponent("../../shell/settings/AppearancePage.qml")
        compare(component.status,Component.Ready,component.errorString())
        const page=component.createObject(test,{width:600})
        const mode=page.itemFor("mode"),font=page.itemFor("fontSize")
        verify(mode!==null);verify(font!==null)
        wait(0)
        compare(mode.width,584)
        tryVerify(function(){return font.y>mode.y})
        page.width=1100;wait(0)
        compare(page.itemFor("mode"),mode)
        verify(mode.width<560)
        tryVerify(function(){return font.x>mode.x})
        compare(font.y,mode.y)
        page.width=440;wait(0)
        compare(mode.width,424)
        tryVerify(function(){return font.y>mode.y})
        page.destroy()
    }
}
