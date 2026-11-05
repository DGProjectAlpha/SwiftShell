pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../logic/weather.js" as Weather
Singleton {
    id:root
    readonly property bool weatherEnabled:SettingsStore.weatherEnabled
    readonly property var location: {
        try {const value=JSON.parse(SettingsStore.weatherLocationJson);return Weather.validLocation(value) ? value : null}
        catch(error){return null}
    }
    readonly property bool configured:location!==null
    readonly property bool available:weatherEnabled && configured && forecast!==null
    property var forecast:null
    property var searchResults:[]
    property string searchAttribution:""
    property string searchQuery:""
    property string error:""
    property string message:""
    property string action:""
    property var pendingRequest:({})
    property int generation:0
    property int requestGeneration:0
    property string configurationKey:""
    property bool refreshPending:false
    property double now:Date.now()
    readonly property bool busy:bridge.running
    readonly property string updated:forecast ? Weather.ageLabel(forecast.fetchedAt,now) : "Not updated"
    readonly property string barText:forecast ? Weather.temperature(forecast.current.temperature) : "—"
    function request(next,values) {
        if(bridge.running){if(next==="forecast")refreshPending=true;return false}
        action=next;error="";message="";requestGeneration=generation
        pendingRequest=Object.assign({action:next},values || {})
        bridge.running=true;return true
    }
    function refresh(force) {
        if(!weatherEnabled || !configured)return false
        return request("forecast",{location:location,units:SettingsStore.weatherUnits,refreshMinutes:SettingsStore.weatherRefreshMinutes,force:force===true})
    }
    function search(query) {
        if(busy)return false
        searchQuery=String(query || "").trim();searchResults=[];searchAttribution=""
        return request("search",{query:searchQuery})
    }
    function choose(place) {
        if(!Weather.validLocation(place))return false
        const saved=SettingsStore.setWeatherPreferences({enabled:true,locationMode:"manual",query:searchQuery,locationJson:JSON.stringify(place)})
        if(saved){searchResults=[];searchAttribution=""}
        return saved
    }
    function locate(){return request("locate",{})}
    function configure() {
        const next=[weatherEnabled,SettingsStore.weatherLocationJson,SettingsStore.weatherUnits].join("|")
        if(next===configurationKey)return
        configurationKey=next;generation++;forecast=null;error="";message="";refreshPending=weatherEnabled && configured
        if(bridge.running)return
        refreshPending=false
        if(weatherEnabled && configured)Qt.callLater(function(){root.refresh(false)})
    }
    Component.onCompleted:configureDelay.restart()
    Connections {
        target:SettingsStore
        function onWeatherEnabledChanged(){configureDelay.restart()}
        function onWeatherLocationJsonChanged(){configureDelay.restart()}
        function onWeatherUnitsChanged(){configureDelay.restart()}
    }
    Timer {id:configureDelay;interval:0;onTriggered:root.configure()}
    Timer {interval:Math.max(10,SettingsStore.weatherRefreshMinutes)*60000;running:root.weatherEnabled && root.configured;repeat:true;onTriggered:root.refresh(false)}
    Timer {interval:60000;running:root.weatherEnabled && root.forecast!==null;repeat:true;onTriggered:root.now=Date.now()}
    Process {
        id:bridge
        objectName:"weatherBridge"
        command:["python3",Quickshell.shellDir+"/helpers/weatherctl.py"]
        stdinEnabled:true
        onStarted:write(JSON.stringify(root.pendingRequest)+"\n")
        stdout:StdioCollector {id:reply;waitForEnd:true}
        onExited:function(code,status) {
            if(root.requestGeneration!==root.generation){if(root.refreshPending){root.refreshPending=false;Qt.callLater(function(){root.refresh(false)})}return}
            const completed=root.action
            try {
                const result=JSON.parse(reply.text)
                if(code!==0 || !result.ok)throw new Error(result.message || "Weather services are unavailable.")
                root.error="";root.message=result.message || ""
                if(completed==="search"){root.searchResults=result.locations || [];root.searchAttribution=result.attribution || "";if(root.searchResults.length===0)root.message="No matching places. Try a nearby city or a more complete address."}
                if(completed==="locate")SettingsStore.setWeatherPreferences({enabled:true,locationMode:"automatic",locationJson:JSON.stringify(result.location)})
                if(completed==="forecast"){root.forecast=result.data;root.now=Date.now()}
            } catch(failure){root.error=String(failure.message || "Weather services are unavailable.")}
            if(root.refreshPending){root.refreshPending=false;Qt.callLater(function(){root.refresh(false)})}
        }
    }
}
