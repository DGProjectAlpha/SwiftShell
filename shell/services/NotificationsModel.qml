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
    property double calendarNow:Date.now()
    readonly property bool scheduled:Notifications.scheduledQuiet(SettingsStore.notificationQuietHoursEnabled,SettingsStore.notificationQuietStart,SettingsStore.notificationQuietEnd,SettingsStore.notificationQuietDays,calendarNow)
    readonly property bool quiet:center.dnd
    property var soundComponent:null
    readonly property bool soundAvailable:soundComponent!==null && soundComponent.status===Component.Ready
    readonly property bool soundReady:sound.item!==null && sound.item.available
    readonly property string soundReason:!soundAvailable ? "Sounds need the optional multimedia integration." : sound.item ? sound.item.reason : SettingsStore.notificationSoundEnabled ? "Preparing notification sound…" : ""
    property double lastSoundAt:0
    property int replyTarget:0
    signal replyRequested(int notificationId,string text)
    signal drawerRequested()
    signal soundPlayed()
    signal closeRequested(int notificationId, string kind)
    signal actionRequested(int notificationId, string identifier)
    signal clearRequested()
    signal localActionRequested(string kind)
    property int localSequence: -1000
    property var localActions: ({})
    function publishLocal(summary,body,kind) {
        if(SettingsStore.notificationOwnership !== "on") return false
        const id=--localSequence
        receive({id:id,local:true,appName:kind ? "Clock" : "SwiftShell",summary:summary,body:body,desktopEntry:kind ? "swiftshell.clock" : "swiftshell",expireTimeout:-1,
            actions:kind ? [{text:"Open Clock",identifier:"default"}] : []})
        if(kind && root.entries.some(function(item){return item.id===id})){const next=Object.assign({},localActions);next[id]=kind;localActions=next}
        return true
    }

    function reduce(action) {
        root.center=Notifications.reduceNotifications(root.center,action)
        const ids=Notifications.allEntries(root.center).map(function(item){return item.id})
        const kept={};Object.keys(localActions).forEach(function(id){if(ids.indexOf(Number(id))!==-1) kept[id]=localActions[id]})
        localActions=kept
        if(replyTarget && !root.entries.some(function(item){return item.id===replyTarget && item.nativeAlive && item.hasInlineReply}))replyTarget=0
    }
    function noteServer(state) { root.serverState=["waiting","running","failed"].indexOf(state)!==-1 ? state : "off" }
    function configure(ownership,dnd,policiesJson) {
        root.calendarNow=Date.now()
        root.reduce({type:"configure",ownership:ownership,dnd:dnd || SettingsStore.notificationQuietUntil>calendarNow || root.scheduled,
            policies:policiesJson || "{}",historyLimit:SettingsStore.notificationHistoryLimit})
    }
    function refreshConfiguration() { configure(SettingsStore.notificationOwnership,SettingsStore.notificationDnd,SettingsStore.notificationPoliciesJson) }
    function receive(raw) {
        const existed=entries.some(function(item){return item.id===raw.id})
        root.refreshConfiguration()
        const value=Object.assign({},raw)
        if(value.expireTimeout===undefined || value.expireTimeout<0)value.expireTimeout=value.urgency==="critical" ? 0 : SettingsStore.notificationDuration
        root.reduce({type:"receive",notification:value})
        const route=root.center.lastRoute.id===raw.id ? root.center.lastRoute.disposition : "ignored"
        if(route==="banner" && !existed && !raw.preview && !raw.suppressSound && !root.quiet && SettingsStore.notificationSoundEnabled)playSound()
        return route
    }
    function playSound() {
        if(!soundReady || Date.now()-lastSoundAt<500)return false
        if(!sound.item.playNotification())return false
        lastSoundAt=Date.now();soundPlayed();return true
    }
    function startReply(id) {
        const item=entries.find(function(row){return row.id===id})
        if(!item || !item.nativeAlive || !item.hasInlineReply)return false
        replyTarget=id;drawerRequested();return true
    }
    function sendReply(id,text) {
        const item=entries.find(function(row){return row.id===id})
        if(typeof text!=="string" || !text.trim() || text.length>4096 || text.indexOf("\0")>=0 || !item || !item.nativeAlive || !item.hasInlineReply)return false
        replyRequested(id,text);replyTarget=0;return true
    }
    function preview() {
        root.reduce({type:"preview",notification:{appName:"Preview",expireTimeout:SettingsStore.notificationDuration,summary:"A little room to focus",body:"Notifications use the same glass, spacing and typography as your desktop.",urgency:"normal"}})
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

    Component.onCompleted:soundComponent=Qt.createComponent(Qt.resolvedUrl("../notifications/NotificationSound.qml"))
    Loader {id:sound;active:root.soundAvailable && SettingsStore.notificationSoundEnabled;sourceComponent:root.soundComponent}
    // Calendar deadline, active only for scheduled quiet hours; never polls a service.
    Timer {
        interval:Math.max(20,60000-(root.calendarNow%60000));repeat:true
        running:SettingsStore.notificationQuietHoursEnabled && SettingsStore.notificationOwnership==="on"
        onTriggered:root.refreshConfiguration()
    }
    Connections {
        target:SettingsStore
        function onNotificationOwnershipChanged(){root.refreshConfiguration()}
        function onNotificationDndChanged(){root.refreshConfiguration()}
        function onNotificationPoliciesJsonChanged(){root.refreshConfiguration()}
        function onNotificationQuietUntilChanged(){root.refreshConfiguration()}
        function onNotificationQuietHoursEnabledChanged(){root.refreshConfiguration()}
        function onNotificationQuietStartChanged(){root.refreshConfiguration()}
        function onNotificationQuietEndChanged(){root.refreshConfiguration()}
        function onNotificationQuietDaysChanged(){root.refreshConfiguration()}
        function onNotificationHistoryLimitChanged(){root.refreshConfiguration()}
    }
    readonly property double nextWake: {
        const deadlines=entries.filter(function(item){return item.snoozedUntil>0}).map(function(item){return item.snoozedUntil})
        if(SettingsStore.notificationQuietUntil>0)deadlines.push(SettingsStore.notificationQuietUntil)
        return deadlines.length ? Math.min.apply(null,deadlines) : 0
    }
    property double wakeNow:Date.now()
    Timer {
        id:wake
        interval:Math.max(1,Math.min(86400000,root.nextWake-root.wakeNow))
        running:root.nextWake>0
        repeat:false
        onTriggered:{
            root.wakeNow=Date.now()
            root.reduce({type:"tick"})
            if(SettingsStore.notificationQuietUntil>0 && SettingsStore.notificationQuietUntil<=root.wakeNow)SettingsStore.setNotificationPreferences({quietUntil:0})
            root.refreshConfiguration()
            if(root.nextWake>0)wake.restart()
        }
    }
    onNextWakeChanged:{wakeNow=Date.now();if(wake && nextWake>0)wake.restart()}
}
