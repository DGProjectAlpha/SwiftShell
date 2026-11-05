//@ pragma ShellId swiftshell-network-auth-audit
import QtQuick
import Quickshell
import Quickshell.Io
import "services" as Services
import "settings" as Settings
ShellRoot {
    id:audit
    function named(item,name,seen) {
        if(!item || seen.indexOf(item)>=0)return []
        seen.push(item)
        let found=item.objectName===name ? [item] : []
        let children=[]
        if(item.data)for(let index=0;index<item.data.length;index++)children.push(item.data[index])
        if(item.children)for(let index=0;index<item.children.length;index++)children.push(item.children[index])
        if(item.contentItem)children.push(item.contentItem)
        for(let child of children)found=found.concat(named(child,name,seen))
        return found
    }
    function box(item) {
        if(!item)return null
        if(typeof item.mapToItem==="function") {
            const point=item.mapToItem(window.contentItem,0,0)
            return {x:point.x,y:point.y,width:item.width,height:item.height}
        }
        return {x:item.x,y:item.y,width:item.width,height:item.height}
    }
    function item(name) {return named(page,name,[])[0] || null}
    IpcHandler {
        target:"networkAudit"
        function state():string {
            const buttons=audit.named(page,"networkAccessPointConnect",[])
            const visible=buttons.map(function(item){return audit.box(item)}).filter(function(rect){return rect.y>50 && rect.y+rect.height<window.height-40})
            return JSON.stringify({ready:Services.NetworkService.available && !Services.NetworkService.busy,authOpen:page.authOpen,confirmationOpen:page.confirmationOpen,wifiEnabled:Services.NetworkService.wifiEnabled,error:Services.NetworkService.error,width:window.width,height:window.height,ap:visible[0] || null,password:audit.box(audit.item("networkPasswordDialog")),passwordFocused:audit.item("wifiPassword").activeFocus,secretEmpty:audit.item("wifiPassword").text==="",cancel:audit.box(audit.item("networkPasswordCancel")),toggle:audit.box(audit.item("networkWifiToggle")),confirm:audit.box(audit.item("networkDisconnectConfirm")),confirmBox:audit.box(audit.item("networkDisconnectDialog"))})
        }
        function scroll(offset:int):void {scroller.contentY=offset}
    }
    FloatingWindow {
        id:window
        title:"SwiftShell Network Auth Audit"
        visible:true
        implicitWidth:1000;implicitHeight:700
        color:"#161616"
        Flickable {
            id:scroller
            anchors.fill:parent
            contentWidth:width;contentHeight:page.height
            clip:true
            Settings.NetworkPage {id:page;width:scroller.width-40;x:20;y:16}
        }
    }
    Timer {interval:30000;running:true;onTriggered:Qt.quit()}
}
