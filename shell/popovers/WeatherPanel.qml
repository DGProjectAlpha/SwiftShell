import QtQuick
import "../components"
import "../services"
import "../themes"
import "../logic/weather.js" as Weather
Column {
    id:panel
    width:400
    spacing:Theme.settingsSpacing+4
    signal settingsRequested()
    property string expandedDay:""
    property string chartMode:"probability"
    readonly property var forecast:WeatherService.forecast
    readonly property var current:forecast ? forecast.current : ({})
    readonly property var units:forecast ? forecast.units : ({temperature:SettingsStore.weatherUnits==="imperial" ? "°F" : "°C",wind:SettingsStore.weatherUnits==="imperial" ? "mph" : "km/h",precipitation:SettingsStore.weatherUnits==="imperial" ? "in" : "mm"})
    function diagnostics(){return {enabled:WeatherService.enabled,configured:WeatherService.configured,available:WeatherService.available,busy:WeatherService.busy,days:forecast ? forecast.days.length : 0,hours:forecast ? forecast.hours.length : 0,expanded:expandedDay!=="",stale:forecast ? forecast.stale===true : false}}
    Row {
        width:parent.width;spacing:4
        Text {width:parent.width-refresh.width-settings.width-8;height:32;verticalAlignment:Text.AlignVCenter;text:"Weather";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        FlatButton {id:refresh;objectName:"weatherRefresh";label:WeatherService.busy ? "Updating…" : "Refresh";enabled:WeatherService.enabled && WeatherService.configured && !WeatherService.busy;onActivated:WeatherService.refresh(true)}
        FlatButton {id:settings;objectName:"weatherSettings";label:"Settings";onActivated:panel.settingsRequested()}
    }
    Text {width:parent.width;visible:WeatherService.location!==null;text:WeatherService.location ? WeatherService.location.name : "";textFormat:Text.PlainText;wrapMode:Text.WordWrap;maximumLineCount:2;elide:Text.ElideRight;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
    Text {
        visible:!WeatherService.available;width:parent.width;wrapMode:Text.WordWrap;topPadding:12;bottomPadding:12
        text:!WeatherService.enabled ? "Turn on weather and choose a location in Settings." : !WeatherService.configured ? "Choose a city or address in Settings to see its forecast." : WeatherService.busy ? "Fetching the forecast…" : WeatherService.error || "The forecast is unavailable. Try Refresh."
        textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize
    }
    Column {
        width:parent.width;visible:WeatherService.available;spacing:Theme.settingsSpacing+6
        Row {
            width:parent.width;spacing:16
            WeatherGlyph {width:66;height:66;anchors.verticalCenter:parent.verticalCenter;code:panel.current.code;daylight:panel.current.isDay!==false;foreground:Theme.settingsText}
            Column {
                width:parent.width-82;spacing:2
                Text {objectName:"weatherCurrentTemperature";text:Weather.temperature(panel.current.temperature,panel.units.temperature);color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:36;font.weight:Font.Light}
                Text {width:parent.width;text:Weather.condition(panel.current.code);color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+1}
                Text {text:"Feels like "+Weather.temperature(panel.current.feelsLike);color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            }
        }
        Grid {
            width:parent.width;columns:2;columnSpacing:16;rowSpacing:8
            Repeater {
                model:[{label:"Humidity",value:Weather.percent(panel.current.humidity)},{label:"Wind",value:Weather.amount(panel.current.wind,panel.units.wind)+" "+Weather.windDirection(panel.current.windDirection)},{label:"Precipitation",value:Weather.amount(panel.current.precipitation,panel.units.precipitation)},{label:"Today",value:panel.forecast && panel.forecast.days.length ? Weather.temperature(panel.forecast.days[0].low)+" / "+Weather.temperature(panel.forecast.days[0].high) : "—"}]
                delegate:Column {
                    required property var modelData
                    width:(panel.width-16)/2;spacing:2
                    Text {text:modelData.label;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                    Text {text:modelData.value;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                }
            }
        }
        Text {text:"Next 24 hours";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
        WeatherHours {objectName:"weatherUpcomingHours";width:parent.width;hours:panel.forecast ? panel.forecast.hours : []}
        Row {
            width:parent.width;spacing:4
            FlatButton {objectName:"weatherRainChance";label:"Rain chance";emphasized:panel.chartMode==="probability";onActivated:panel.chartMode="probability"}
            FlatButton {objectName:"weatherRainAmount";label:"Amount";emphasized:panel.chartMode==="precipitation";onActivated:panel.chartMode="precipitation"}
        }
        PrecipitationChart {objectName:"weatherRainChart";width:parent.width;hours:panel.forecast ? panel.forecast.hours : [];mode:panel.chartMode;unit:panel.units.precipitation}
        Text {text:"7-day forecast";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
        Repeater {
            model:panel.forecast ? panel.forecast.days : []
            delegate:Column {
                id:day;required property var modelData
                width:panel.width;spacing:8
                readonly property bool expanded:panel.expandedDay===modelData.key
                FlatButton {
                    objectName:"weatherDay-"+day.modelData.key
                    width:parent.width;height:42;label:""
                    Accessible.name:day.modelData.label+" "+Weather.condition(day.modelData.code)+", low "+Weather.temperature(day.modelData.low)+", high "+Weather.temperature(day.modelData.high)+". "+(day.expanded ? "Collapse" : "Show hourly forecast")
                    onActivated:panel.expandedDay=day.expanded ? "" : day.modelData.key
                    Row {
                        anchors.fill:parent;anchors.margins:5;spacing:6
                        Text {width:96;height:parent.height;verticalAlignment:Text.AlignVCenter;text:day.modelData.label;textFormat:Text.PlainText;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                        WeatherGlyph {width:26;height:26;anchors.verticalCenter:parent.verticalCenter;code:day.modelData.code;foreground:Theme.settingsText}
                        Text {width:52;height:parent.height;verticalAlignment:Text.AlignVCenter;text:Weather.percent(day.modelData.probability);color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                        Text {width:Math.max(70,panel.width-96-26-52-16-10-24);height:parent.height;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:Weather.temperature(day.modelData.low)+"  /  "+Weather.temperature(day.modelData.high);color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                        Text {width:16;height:parent.height;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignRight;text:day.expanded ? "⌄" : "›";color:Theme.settingsMuted;font.pixelSize:16}
                    }
                }
                Column {
                    visible:day.expanded;width:parent.width;spacing:8
                    WeatherHours {width:parent.width;hours:day.modelData.hours}
                    PrecipitationChart {width:parent.width;hours:day.modelData.hours;mode:panel.chartMode;unit:panel.units.precipitation}
                    Text {width:parent.width;wrapMode:Text.WordWrap;text:"Precipitation "+Weather.amount(day.modelData.precipitation,panel.units.precipitation)+"  ·  UV "+Weather.amount(day.modelData.uv,"")+"\nSunrise "+day.modelData.sunrise+"  ·  Sunset "+day.modelData.sunset;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
                }
            }
        }
        Column {
            width:parent.width;spacing:5
            Text {text:"Air quality";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
            Text {objectName:"weatherAirQuality";width:parent.width;wrapMode:Text.WordWrap;text:panel.forecast ? (Weather.number(panel.forecast.airQuality.usAqi) ? Math.round(panel.forecast.airQuality.usAqi)+" U.S. AQI · "+Weather.aqi(panel.forecast.airQuality.usAqi) : "Air quality data is unavailable.") : "";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:panel.forecast ? "PM₂.₅ "+Weather.amount(panel.forecast.airQuality.pm25,"µg/m³")+"  ·  PM₁₀ "+Weather.amount(panel.forecast.airQuality.pm10,"µg/m³")+"\nModel estimate for the area" : "";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        Text {width:parent.width;wrapMode:Text.WordWrap;text:(panel.forecast && panel.forecast.stale ? "Saved forecast · " : "")+WeatherService.updated+(WeatherService.message ? "\n"+WeatherService.message : "")+(WeatherService.error ? "\n"+WeatherService.error : "");textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        FlatButton {label:"Weather: Open-Meteo · Air quality: CAMS";width:parent.width;onActivated:Qt.openUrlExternally("https://open-meteo.com/")}
    }
}
