import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/logic/notifications.js" as Notes
TestCase {
    id:test
    name:"NotificationCenter"
    when:windowShown
    visible:true;width:480;height:700
    property var saved:null
    property var savedSettings:null
    property var card:null
    SignalSpy {id:actionSpy;target:Services.NotificationsModel;signalName:"actionRequested"}
    SignalSpy {id:localSpy;target:Services.NotificationsModel;signalName:"localActionRequested"}
    function init(){
        saved=Services.NotificationsModel.center
        savedSettings=Services.SettingsStore.snapshot()
        Services.SettingsStore.acceptWrites=false
        Services.SettingsStore.setNotificationOwnership("on")
        Services.NotificationsModel.center=Notes.emptyCenter()
        Services.NotificationsModel.configure("on",false,"{}")
        actionSpy.clear();localSpy.clear()
    }
    function cleanup(){
        if(card){card.destroy();card=null}
        Services.NotificationsModel.center=saved
        Services.SettingsStore.applyDocument(savedSettings)
    }
    function makeCard(){
        const component=Qt.createComponent("../../shell/notifications/NotificationCard.qml")
        compare(component.status,Component.Ready,component.errorString())
        card=component.createObject(test,{width:360,entry:Services.NotificationsModel.center.live[0]})
        verify(card!==null)
        waitForRendering(card)
    }
    function test_real_dismiss_and_snooze_buttons(){
        Services.NotificationsModel.receive({id:80,appName:"Fixture",summary:"Snooze me"})
        makeCard()
        mouseClick(findChild(card,"notificationSnooze"))
        compare(Services.NotificationsModel.center.live.length,0)
        compare(Services.NotificationsModel.snoozedCount,1)
        card.entry=Services.NotificationsModel.center.history[0]
        waitForRendering(card)
        mouseClick(findChild(card,"notificationDismiss"))
        compare(Services.NotificationsModel.entries.length,0)
    }
    function test_default_action_and_local_clock_routing(){
        Services.NotificationsModel.receive({id:81,summary:"Open me",actions:[{text:"Open",identifier:"default"}]})
        makeCard()
        verify(card.canOpen)
        mouseClick(findChild(card,"notificationOpen"),150,40)
        compare(actionSpy.count,1);compare(actionSpy.signalArguments[0][0],81)
        compare(actionSpy.signalArguments[0][1],"default")
        verify(Services.NotificationsModel.publishLocal("Timer finished","Ready","timer"))
        const local=Services.NotificationsModel.center.live.find(function(item){return item.local})
        verify(local!==undefined)
        Services.NotificationsModel.hideBanner(local.id)
        verify(Services.NotificationsModel.center.history.find(function(item){return item.id===local.id}).nativeAlive)
        Services.NotificationsModel.invoke(local.id,"default")
        compare(localSpy.count,1);compare(localSpy.signalArguments[0][0],"timer")
    }
    function test_drawer_and_settings_load(){
        const component=Qt.createComponent("../../shell/notifications/NotificationDrawer.qml")
        compare(component.status,Component.Ready,component.errorString())
        card=component.createObject(test)
        verify(card!==null)
        Services.NotificationsModel.receive({id:82,summary:"Visible in drawer"})
        tryCompare(Services.NotificationsModel,"unreadCount",0)
        compare(card.diagnostics().count,1)
        card.filter="snoozed";compare(card.filtered.length,0)
        Services.NotificationsModel.snooze(82,5);compare(card.filtered.length,1)
    }
}
