import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/popovers" as Popovers
import "../../shell/notifications" as NotificationUI
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
    SignalSpy {id:replySpy;target:Services.NotificationsModel;signalName:"replyRequested"}
    function test_clock_duration_and_dnd_are_shared() {
        verify(Services.SettingsStore.setNotificationPreferences({bannerDuration:15}))
        Services.NotificationsModel.publishLocal("Timer","Ready","timer")
        compare(Services.NotificationsModel.center.live[0].expireMs,15000)
        Services.SettingsStore.setNotificationDnd(true)
        compare(Services.NotificationsModel.center.live.length,0)
        compare(Services.NotificationsModel.center.history.length,1)
        Services.SettingsStore.setNotificationDnd(false)
        compare(Services.NotificationsModel.center.live.length,0)
        verify(!Services.SettingsStore.setNotificationPreferences({soundVolume:20}))
    }
    function test_privacy_reply_and_draft_survive_updates() {
        replySpy.clear()
        Services.NotificationsModel.receive({id:90,appName:"Fixture",summary:"Private summary",body:"Private body",hasInlineReply:true,replyPlaceholder:"Reply to fixture"})
        const component=Qt.createComponent("../../shell/notifications/NotificationDrawer.qml")
        compare(component.status,Component.Ready,component.errorString())
        card=component.createObject(test)
        waitForRendering(card)
        const original=findChild(card,"notificationCard-90")
        verify(original!==null)
        const field=findChild(original,"notificationReplyField")
        field.forceActiveFocus();for(const letter of "owned reply")keyClick(letter===" " ? Qt.Key_Space : letter.toUpperCase().charCodeAt(0))
        compare(field.text,"owned reply")
        Services.NotificationsModel.receive({id:90,appName:"Fixture",summary:"Updated",hasInlineReply:true})
        Services.NotificationsModel.receive({id:91,appName:"Fixture",summary:"Another message"})
        waitForRendering(card)
        compare(findChild(card,"notificationCard-90"),original)
        compare(field.text,"owned reply")
        verify(field.activeFocus)
        mouseClick(findChild(original,"notificationReplySend"))
        compare(replySpy.count,1);compare(replySpy.signalArguments[0][0],90);compare(replySpy.signalArguments[0][1],"owned reply")
        compare(field.text,"")
        Services.NotificationsModel.closed(90)
        verify(!Services.NotificationsModel.sendReply(90,"after close"))
    }
    function test_banner_previews_and_action_labels_are_plain() {
        Services.NotificationsModel.receive({id:92,appName:"Fixture",summary:"Private title",body:"Private body",hasInlineReply:true,actions:[{identifier:"action",text:"<b>Literal action</b>"}]})
        makeCard();card.banner=true
        Services.SettingsStore.setNotificationPreferences({previewMode:"app-only"})
        verify(card.hiddenPreview)
        verify(!findChild(card,"notificationReplyOpen").visible)
        Services.SettingsStore.setNotificationPreferences({previewMode:"full"})
        verify(!card.hiddenPreview)
        verify(findChild(card,"notificationReplyOpen").visible)
        function labels(item) {
            if(item.text==="<b>Literal action</b>")compare(item.textFormat,Text.PlainText)
            for(const child of item.children || [])labels(child)
        }
        labels(card)
    }
    Component {
        id:scrollingDrawer
        Popovers.PopoverSurface {maximumHeight:300;NotificationUI.NotificationDrawer {}}
    }
    function test_reply_stays_visible_when_new_messages_push_it_down() {
        Services.NotificationsModel.receive({id:95,appName:"Fixture",summary:"Original",hasInlineReply:true})
        card=scrollingDrawer.createObject(test,{width:420,height:300})
        verify(card!==null)
        waitForRendering(card)
        const message=findChild(card,"notificationCard-95"),field=findChild(message,"notificationReplyField"),viewport=findChild(card,"popoverScroll")
        field.forceActiveFocus()
        Services.NotificationsModel.receive({id:96,appName:"Fixture",summary:"New message",body:"An incoming message must not push the active reply out of view",hasInlineReply:true})
        waitForRendering(card)
        tryVerify(function(){const point=field.mapToItem(viewport,0,0);return point.y>=-1 && point.y+field.height<=viewport.height+1})
        verify(field.activeFocus)
    }
    function test_explicit_banner_preview_uses_duration_without_history_or_sound() {
        Services.SettingsStore.setNotificationDnd(true)
        Services.SettingsStore.setNotificationPreferences({bannerDuration:10})
        Services.NotificationsModel.preview()
        compare(Services.NotificationsModel.center.live.length,1)
        verify(Services.NotificationsModel.center.live[0].preview)
        compare(Services.NotificationsModel.center.live[0].expireMs,10000)
        compare(Services.NotificationsModel.entries.length,0)
    }
}
