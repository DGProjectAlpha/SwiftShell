import QtQuick
import QtTest
import "../../shell/services" as Services
TestCase {
    id:test
    name:"ScreenshotReview"
    when:windowShown
    visible:true;width:600;height:600
    property var panel:null
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        const component=Qt.createComponent("../../shell/screenshots/ScreenshotPanel.qml")
        compare(component.status,Component.Ready,component.errorString())
        panel=component.createObject(test)
        verify(panel!==null)
        Services.ScreenshotService.available=true
        Services.ScreenshotService.regionAvailable=true
        Services.ScreenshotService.mode="region"
        Services.ScreenshotService.delaySeconds=0
        waitForRendering(panel)
    }
    function cleanup() {if(Services.ScreenshotService.capturing)Services.ScreenshotService.cancel();panel.destroy();panel=null;Services.ScreenshotService.open=false;Services.ScreenshotService.token="";Services.ScreenshotService.imageUrl=""}
    function test_preview_actions_require_an_image() {
        verify(!Services.ScreenshotService.copy())
        verify(!Services.ScreenshotService.saveAs())
        verify(!findChild(panel,"screenshotCopy").visible)
        Services.ScreenshotService.token="fixture"
        Services.ScreenshotService.imageUrl="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5FoAAAAASUVORK5CYII="
        verify(findChild(panel,"screenshotCopy").visible)
        verify(findChild(panel,"screenshotSave").visible)
    }
    function test_mode_controls_select_capture_mode() {
        mouseClick(findChild(panel,"screenshotDisplay"))
        compare(Services.ScreenshotService.mode,"output")
        mouseClick(findChild(panel,"screenshotArea"))
        compare(Services.ScreenshotService.mode,"region")
    }
    function test_delay_stays_visible_and_can_cancel() {
        Services.ScreenshotService.delaySeconds=3
        Services.ScreenshotService.open=true
        verify(Services.ScreenshotService.capture("region","DP-1"))
        verify(Services.ScreenshotService.open)
        verify(Services.ScreenshotService.busy)
        verify(findChild(panel,"screenshotCancel").visible)
        waitForRendering(panel)
        mouseClick(findChild(panel,"screenshotCancel"))
        verify(Services.ScreenshotService.open)
        verify(!Services.ScreenshotService.busy)
    }
    function test_closing_cancels_pending_countdown() {
        Services.ScreenshotService.delaySeconds=5
        verify(Services.ScreenshotService.capture("region","DP-1"))
        Services.ScreenshotService.close()
        verify(!Services.ScreenshotService.open)
        verify(!Services.ScreenshotService.busy)
        compare(Services.ScreenshotService.countdown,0)
    }
    function test_reopening_cancels_previous_capture_instead_of_staying_busy() {
        Services.ScreenshotService.delaySeconds=5
        verify(Services.ScreenshotService.capture("region","DP-1"))
        verify(Services.ScreenshotService.busy)
        Services.ScreenshotService.show("DP-1")
        verify(Services.ScreenshotService.open)
        verify(!Services.ScreenshotService.busy)
        compare(Services.ScreenshotService.countdown,0)
        verify(!Services.ScreenshotService.failed)
    }
    function test_close_and_unavailable_capture_are_truthful() {
        Services.ScreenshotService.open=true
        mouseClick(findChild(panel,"screenshotClose"))
        verify(!Services.ScreenshotService.open)
        Services.ScreenshotService.available=false
        verify(!Services.ScreenshotService.capture("output","DP-1"))
        verify(Services.ScreenshotService.failed)
        verify(Services.ScreenshotService.message!=="")
    }
}
