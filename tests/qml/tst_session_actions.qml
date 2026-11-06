import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/popovers" as Popovers
TestCase {
    id:test
    name:"SharedSessionActions"
    when:windowShown
    visible:true;width:600;height:900
    property var section:null
    property var worker:null
    property var reply:null
    Component {id:sectionComponent;Popovers.PowerSection {width:300}}
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        worker=findChild(Services.SessionActions,"sessionActionBridge")
        reply=findChild(Services.SessionActions,"sessionActionReply")
        worker.running=false
        section=sectionComponent.createObject(test)
        verify(section!==null)
        worker.running=false;Services.SessionActions.operation="snapshot"
        const actions={}
        for(const action of ["lock","suspend","logout","reboot","poweroff"])actions[action]={available:true,reason:""}
        reply.text=JSON.stringify({ok:true,actions:actions});worker.exited(0,0)
        Services.LauncherModel.confirmId="";Services.LauncherModel.notice=""
    }
    function cleanup() {
        section.destroy();section=null;worker.running=false
        Services.LauncherModel.confirmId="";Services.LauncherModel.notice=""
        Services.SessionActions.error="";Services.SessionActions.notice=""
    }
    function test_logout_requires_confirmation_and_targets_the_shared_helper() {
        const button=findChild(section,"session-action-logout")
        verify(button!==null);verify(button.enabled)
        mouseClick(button)
        compare(section.confirmId,"logout");compare(worker.running,false)
        mouseClick(button)
        compare(section.confirmId,"");compare(worker.running,true)
        compare(worker.command[worker.command.length-1],"logout")
        verify(worker.command[1].endsWith("/helpers/sessionctl.py"))
    }
    function test_lock_signout_requires_confirmation_and_waits_for_backend() {
        mouseClick(findChild(section,"session-action-lock"))
        compare(section.confirmId,"lock");verify(!Services.SessionActions.busy)
        mouseClick(findChild(section,"session-action-lock"))
        compare(Services.SessionActions.operation,"lock")
        verify(Services.SessionActions.busy)
        verify(Services.SessionActions.notice.indexOf("Requesting")>=0)
        reply.text=JSON.stringify({ok:true,message:"Signing out to the system login screen…"})
        worker.running=false;worker.exited(0,0)
        compare(Services.SessionActions.notice,"Signing out to the system login screen…")
    }
    function test_failed_suspend_is_visible_in_the_power_panel() {
        Services.SessionActions.perform("suspend")
        reply.text=JSON.stringify({ok:false,message:"Sleep is blocked by an application."})
        worker.running=false;worker.exited(1,0)
        compare(Services.SessionActions.error,"Sleep is blocked by an application.")
        const status=findChild(section,"sessionActionStatus")
        verify(status.visible);compare(status.text,Services.SessionActions.error)
    }
    function test_launcher_and_bar_share_failure_and_busy_state() {
        Services.LauncherModel.runPower("logout")
        compare(Services.LauncherModel.confirmId,"logout")
        Services.LauncherModel.runPower("logout")
        compare(Services.SessionActions.operation,"logout")
        verify(Services.LauncherModel.actionBusy)
        reply.text=JSON.stringify({ok:false,message:"The current session is unavailable."})
        worker.running=false;worker.exited(1,0)
        compare(Services.LauncherModel.notice,"The current session is unavailable.")
        compare(findChild(section,"sessionActionStatus").text,Services.LauncherModel.notice)
    }
    function test_capability_refresh_does_not_block_normal_application_launch() {
        Services.SessionActions.operation="snapshot";worker.running=true
        verify(Services.SessionActions.refreshing)
        compare(Services.SessionActions.busy,false)
        compare(Services.LauncherModel.actionBusy,false)
    }
    function test_helper_crash_shows_a_readable_error() {
        Services.SessionActions.perform("lock")
        reply.text="";worker.running=false;worker.exited(1,0)
        compare(Services.SessionActions.error,"Session controls did not respond. Refresh and try again.")
        compare(findChild(section,"sessionActionStatus").text,Services.SessionActions.error)
    }
    function test_missing_greeter_is_disabled_with_an_explanation() {
        const actions=Object.assign({},Services.SessionActions.actions)
        actions.lock={available:false,reason:"The system login screen is unavailable."}
        Services.SessionActions.actions=actions
        compare(findChild(section,"session-action-lock").enabled,false)
        compare(Services.SessionActions.perform("lock"),false)
        verify(Services.SessionActions.error.indexOf("login screen")>=0)
        compare(worker.running,false)
    }
}
