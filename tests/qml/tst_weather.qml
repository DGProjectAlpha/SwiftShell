import QtQuick
import QtTest
import "../../shell/services" as Services
import "../../shell/popovers" as Popovers
import "../../shell/settings" as SettingsUI
TestCase {
    id:test
    name:"WeatherSurfaces"
    when:windowShown
    visible:true;width:1000;height:1700
    property var saved:null
    property var panel:null
    SignalSpy {id:settingsSpy;target:panel;signalName:"settingsRequested"}
    Component {id:panelComponent;Popovers.WeatherPanel {width:400}}
    function fixture() {
        const hours=[],days=[]
        for(let i=0;i<24;i++)hours.push({time:1000+i*3600,day:"2026-11-05",label:String(i).padStart(2,"0")+":00",temperature:8+i*.1,probability:i*4,precipitation:i%4 ? .1 : 0,humidity:70,wind:10,code:61,isDay:i>6 && i<18})
        for(let i=0;i<7;i++)days.push({key:"2026-11-"+String(5+i).padStart(2,"0"),label:i===0 ? "Today" : "Day "+(i+1),date:"Nov "+(5+i),low:4,high:10,probability:60,precipitation:1,uv:2,sunrise:"07:00",sunset:"17:00",code:61,hours:hours})
        return {location:{name:"<b>Literal city</b>",latitude:52.52,longitude:13.405},fetchedAt:Date.now()-60000,current:{temperature:0,feelsLike:-1,humidity:0,wind:10,windDirection:245,precipitation:0,code:61,isDay:true},days:days,hours:hours,airQuality:{usAqi:32,euAqi:20,pm25:5,pm10:9,ozone:40,nitrogenDioxide:12},units:{temperature:"°C",wind:"km/h",precipitation:"mm"},stale:false}
    }
    function init() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/)
        saved=Services.SettingsStore.snapshot()
        verify(Services.SettingsStore.setWeatherPreferences({enabled:true,locationJson:JSON.stringify({name:"<b>Literal city</b>",latitude:52.52,longitude:13.405})}))
        Services.WeatherService.configure()
        wait(1)
        const bridge=findChild(Services.WeatherService,"weatherBridge")
        if(bridge)bridge.running=false
        Services.WeatherService.forecast=fixture();Services.WeatherService.error="";Services.WeatherService.message=""
        panel=panelComponent.createObject(test)
        verify(panel!==null);waitForRendering(panel);settingsSpy.clear()
    }
    function cleanup() {
        panel.destroy();panel=null
        Services.SettingsStore.applyDocument(saved)
        Services.WeatherService.forecast=null;Services.WeatherService.searchResults=[];Services.WeatherService.error="";Services.WeatherService.message=""
        const bridge=findChild(Services.WeatherService,"weatherBridge");if(bridge)bridge.running=false
        wait(1)
    }
    function test_current_zero_temperature_and_rich_forecast() {
        compare(findChild(panel,"weatherCurrentTemperature").text,"0°C")
        compare(panel.diagnostics().days,7)
        compare(panel.diagnostics().hours,24)
        verify(findChild(panel,"weatherAirQuality").text.indexOf("32 U.S. AQI")>=0)
        compare(findChild(panel,"weatherRainChart").mode,"probability")
    }
    function test_daily_row_expands_hourly_and_collapses() {
        const row=findChild(panel,"weatherDay-2026-11-05"),before=panel.implicitHeight
        mouseClick(row)
        compare(panel.expandedDay,"2026-11-05")
        tryVerify(function(){return panel.implicitHeight>before})
        mouseClick(row);compare(panel.expandedDay,"")
    }
    function test_precipitation_mode_buttons_and_settings_action() {
        mouseClick(findChild(panel,"weatherRainAmount"));compare(findChild(panel,"weatherRainChart").mode,"precipitation")
        mouseClick(findChild(panel,"weatherRainChance"));compare(findChild(panel,"weatherRainChart").mode,"probability")
        mouseClick(findChild(panel,"weatherSettings"));compare(settingsSpy.count,1)
    }
    function test_location_is_plain_text_and_missing_aqi_truthful() {
        let matched=false
        function inspect(item){if(item.text==="<b>Literal city</b>"){compare(item.textFormat,Text.PlainText);matched=true}for(let i=0;i<item.children.length;i++)inspect(item.children[i])}
        inspect(panel);verify(matched)
        const data=fixture();data.airQuality.usAqi=null;data.stale=true;Services.WeatherService.forecast=data
        verify(findChild(panel,"weatherAirQuality").text.indexOf("unavailable")>=0)
        verify(panel.diagnostics().stale)
    }
    function test_settings_page_location_and_units_controls_load() {
        const component=Qt.createComponent("../../shell/settings/WeatherPage.qml")
        compare(component.status,Component.Ready,component.errorString())
        const page=component.createObject(test,{width:560})
        verify(page!==null)
        verify(findChild(page,"weatherLocationSearch")!==null)
        verify(findChild(page,"weatherApproximate")!==null)
        compare(findChild(page,"weatherUnits").selectedValue,"metric")
        page.destroy()
    }
    function test_disabled_weather_has_no_automatic_location_request() {
        Services.SettingsStore.setWeatherPreferences({enabled:false,locationJson:"{}",locationMode:"manual"})
        wait(1)
        verify(!Services.WeatherService.weatherEnabled)
        verify(!Services.WeatherService.configured)
        verify(!Services.WeatherService.refresh(false))
        verify(Services.WeatherService.action!=="locate")
    }
}
