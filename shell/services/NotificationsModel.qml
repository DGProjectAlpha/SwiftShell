pragma Singleton
import QtQuick
import Quickshell
import "../logic/notifications.js" as Notifications

Singleton {
    id: root
    property var center: Notifications.emptyCenter()
    property string serverState: "off"
    property string error: ""
    readonly property var entries: Notifications.allEntries(center)
    readonly property int unreadCount: entries.filter(function(item){return item.unread}).length
    readonly property int snoozedCount: entries.filter(function(item){return item.snoozedUntil>0}).length
    readonly property bool quiet: SettingsStore.notificationDnd || SettingsStore.notificationQuietUntil > Date.now()
    signal closeRequested(int notificationId, string kind)
    signal actionRequested(int notificationId, string identifier)
    signal clearRequested()
    signal localActionRequested(string kind)
    property int localSequence: -1000
    property var localActions: ({})
    function publishLocal(summary,body,kind) {
        if(SettingsStore.notificationOwnership !== "on") return false
        const id=--localSequence
        const next=Object.assign({},localActions);if(kind)next[id]=kind;localActions=next
        receive({id:id,local:true,appName:kind ? "Clock" : "SwiftShell",summary:summary,body:body,desktopEntry:kind ? "swiftshell.clock" : "swiftshell",expireTimeout:-1,
            actions:kind ? [{text:"Open Clock",identifier:"default"}] : []})
        return true
    }

    function reduce(action) {
        root.center=Notifications.reduceNotifications(root.center,action)
        const ids=Notifications.allEntries(root.center).map(function(item){return item.id})
        const kept={};Object.keys(localActions).forEach(function(id){if(ids.indexOf(Number(id))!==-1) kept[id]=localActions[id]})
        localActions=kept
    }
    function noteServer(state) { root.serverState=["waiting","running","failed"].indexOf(state)!==-1 ? state : "off" }
    function configure(ownership,dnd,policiesJson) {
        root.reduce({type:"configure",ownership:ownership,dnd:dnd || SettingsStore.notificationQuietUntil>Date.now(),
            policies:policiesJson || "{}",historyLimit:SettingsStore.notificationHistoryLimit})
    }
    function refreshConfiguration() { configure(SettingsStore.notificationOwnership,SettingsStore.notificationDnd,SettingsStore.notificationPoliciesJson) }
    function receive(raw) {
        root.reduce({type:"receive",notification:raw})
        return root.center.lastRoute.id===raw.id ? root.center.lastRoute.disposition : "ignored"
    }
    function preview() {
        root.reduce({type:"preview",notification:{appName:"SwiftShell",summary:"A little room to focus",body:"Notifications use the same glass, spacing and typography as your desktop.",urgency:"normal"}})
    }
    function dismiss(id) { closeRequested(id,"dismiss");root.reduce({type:"dismiss",id:id}) }
    function expire(id) { closeRequested(id,"expire");root.reduce({type:"expire",id:id}) }
    function hideBanner(id) {
        const item=center.live.find(function(row){return row.id===id})
        if(item && item.transient) expire(id)
        else root.reduce({type:"archive",id:id})
    }
    function closed(id) { root.reduce({type:"closed",id:id}) }
    function clearHistory() {clearRequested();root.reduce({type:"clear-history"})}
    function markAllRead() {root.reduce({type:"read-all"})}
    function invoke(id,identifier) {
        if(localActions[id]) {localActionRequested(localActions[id]);dismiss(id);return}
        actionRequested(id,identifier || "default")
    }
    function showNow(id) {root.reduce({type:"wake",id:id})}
    function snooze(id,minutes) {root.reduce({type:"snooze",id:id,durationMs:minutes*60000})}
    function pause(minutes) {SettingsStore.setNotificationPreferences({quietUntil:minutes>0 ? Date.now()+minutes*60000 : 0});refreshConfiguration()}

    Timer {
        interval:1000;repeat:true
        running:root.snoozedCount>0 || SettingsStore.notificationQuietUntil>0
        onTriggered:{
            root.reduce({type:"tick"})
            if(SettingsStore.notificationQuietUntil>0 && SettingsStore.notificationQuietUntil<=Date.now()) {
                SettingsStore.setNotificationPreferences({quietUntil:0})
                root.refreshConfiguration()
            }
        }
    }
    Connections {
        target:SettingsStore
        function onNotificationHistoryLimitChanged(){root.refreshConfiguration()}
        function onNotificationQuietUntilChanged(){root.refreshConfiguration()}
    }
}
