import QtQuick
import QtTest
import Quickshell.Hyprland
import "../../shell/services" as Services
TestCase {
    name:"AppearanceRequestOrdering"
    when:windowShown
    function cleanup() {
        const window=Services.WindowService
        const bridge=findChild(window,"settingsWindowBridge")
        if(bridge)bridge.running=false
        window.queue=[];window.active=false;window.action="";window.lastBlurEnabled=-1
    }
    function test_only_latest_blur_toggle_is_queued() {
        const window=Services.WindowService
        window.lastBlurEnabled=1
        window.request("status")
        verify(window.busy)
        window.request("blur-off");window.request("blur-on");window.request("blur-off")
        compare(window.queue.join(","),"blur-off")
        compare(window.lastBlurEnabled,1)
    }
    function test_pending_opposite_is_cancelled_when_actual_state_is_final() {
        const window=Services.WindowService
        window.lastBlurEnabled=1;window.request("status")
        window.request("blur-off");window.request("blur-on")
        compare(window.queue.length,0)
    }
    function test_inflight_opposite_retains_latest_toggle() {
        const window=Services.WindowService
        window.lastBlurEnabled=1;window.request("blur-off")
        window.request("blur-on");window.request("blur-off");window.request("blur-on")
        compare(window.queue.join(","),"blur-on")
    }
    function test_reload_priority_survives_new_edits() {
        const desktop=Services.DesktopAppearance
        desktop.request("reload",{})
        desktop.request("apply",{radius:14})
        compare(desktop.requestedAction,"reload")
        compare(desktop.pending.radius,14)
        desktop.reloadPending=false;desktop.restore()
    }
    function test_status_probe_does_not_discard_unsent_desktop_edits() {
        const desktop=Services.DesktopAppearance
        desktop.request("apply",{radius:18})
        desktop.request("status",{})
        compare(desktop.requestedAction,"apply")
        compare(desktop.pending.radius,18)
        desktop.request("reload",{})
        compare(desktop.requestedAction,"reload")
        compare(desktop.pending.radius,18)
        desktop.restore()
        compare(desktop.requestedAction,"reload")
        compare(desktop.restorePending,true)
        compare(Object.keys(desktop.pending).length,0)
    }
    function test_opacity_requires_opt_in_and_monitor_focus_does_not_reapply_it() {
        const desktop=Services.DesktopAppearance,store=Services.SettingsStore
        const preferences=store.snapshot(),writes=store.acceptWrites
        const saved={available:desktop.available,managed:desktop.managed,last:desktop.lastOpacityPreference,pending:desktop.pending,requested:desktop.requestedAction,reload:desktop.reloadPending,restore:desktop.restorePending}
        try {
            desktop.available=true;desktop.managed={};desktop.lastOpacityPreference=null
            desktop.pending={};desktop.requestedAction="";desktop.reloadPending=false;desktop.restorePending=false
            store.acceptWrites=true
            desktop.syncOpaqueWindows(false)
            compare(Object.keys(desktop.pending).length,0) // No fresh-install compositor takeover.
            desktop.lastOpacityPreference=null;desktop.managed={rounding:12}
            desktop.syncOpaqueWindows(false)
            compare(desktop.pending.opaqueWindows,store.opaqueWindows)
            desktop.pending={};desktop.requestedAction=""
            for(let i=0;i<12;i++)Hyprland.rawEvent({name:"focusedmon"})
            compare(Object.keys(desktop.pending).length,0)
            compare(desktop.requestedAction,"")
            const appearance=store.snapshot().appearance
            appearance.opaqueWindows=!store.opaqueWindows
            store.setAppearance(appearance)
            compare(store.opaqueWindows,appearance.opaqueWindows)
            compare(desktop.pending.opaqueWindows,appearance.opaqueWindows)
        } finally {
            desktop.available=false;store.acceptWrites=false;store.applyDocument(preferences);store.acceptWrites=writes
            desktop.available=saved.available;desktop.managed=saved.managed;desktop.lastOpacityPreference=saved.last
            desktop.pending=saved.pending;desktop.requestedAction=saved.requested;desktop.reloadPending=saved.reload;desktop.restorePending=saved.restore
        }
    }
}
