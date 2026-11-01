import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/logic/displays.js" as Displays
TestCase {
    name: "DisplayDragging"
    when: windowShown
    width: 800
    height: 600
    visible: true
    function test_drag_moves_without_resizing() {
        const component=Qt.createComponent("../../shell/settings/DisplaysPage.qml")
        compare(component.status, Component.Ready, component.errorString())
        const page=component.createObject(this,{width:700})
        verify(page !== null)
        findChild(Services.DisplayService,"displayBridge").running=false
        page.staged=[Displays.outputFrom({id:"DP-1",name:"DP-1",friendly:"HP X32",width:2560,height:1440,scale:1,x:0,y:0}),Displays.outputFrom({id:"HDMI-A-1",name:"HDMI-A-1",friendly:"Acer",width:1920,height:1080,scale:1.25,x:2560,y:720})]
        const canvas=findChild(page,"displayDiagram")
        const before=canvas.boxes[1]
        const x=before.x+before.width/2, y=before.y+before.height/2
        mousePress(canvas,x,y,Qt.LeftButton)
        verify(canvas.frozen !== null)
        mouseMove(canvas,x+20,y+10,10)
        compare(canvas.boxes[1].width,before.width)
        compare(canvas.boxes[1].height,before.height)
        verify(page.staged[1].x>2560)
        mouseRelease(canvas,x+20,y+10,Qt.LeftButton)
        compare(canvas.frozen,null)
        page.destroy()
    }
}
