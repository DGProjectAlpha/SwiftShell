import QtQuick
import "../components"
import "../services"
import "../themes"
import "../logic/settingsNav.js" as Nav
import "../logic/settingsFocus.js" as Focus
Item {
    id:page
    property string query:""
    property string highlightId:"weatherEnabled"
    signal revealRequested(real y,real itemHeight)
    implicitWidth:560;implicitHeight:column.implicitHeight;height:implicitHeight
    function shows(id){return Nav.controlVisible(query,id)}
    function matchingControls(){return Nav.filterControls(query).filter(function(control){return control.category==="weather"})}
    function itemFor(id){return Focus.findControl(column,id)}
    function revealHighlight() {
        const item=itemFor(highlightId)
        if(!item)return
        Focus.revealAncestors(item)
        Qt.callLater(function(){const point=item.mapToItem(page,0,0);page.revealRequested(point.y,item.height)})
    }
    function focusHighlight() {
        const item=itemFor(highlightId)
        if(!item)return
        revealHighlight()
        Qt.callLater(function(){Focus.focusFirst(item)})
    }
    function moveHighlight(delta) {
        const controls=matchingControls()
        if(!controls.length)return
        let index=controls.findIndex(function(control){return control.id===page.highlightId})
        index=index<0 ? 0 : Math.max(0,Math.min(controls.length-1,index+(delta<0 ? -1 : 1)))
        highlightId=controls[index].id
    }
    function submitLocation(){return searchButton.enabled ? WeatherService.search(locationInput.text) : false}
    onQueryChanged: {const controls=matchingControls();highlightId=controls.length ? controls[0].id : ""}
    onHighlightIdChanged:revealHighlight()
    Column {
        id:column;width:page.width;spacing:Theme.settingsSpacing+6
        Text {text:"Weather";color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+4;font.weight:Font.Medium}
        Text {width:parent.width;wrapMode:Text.WordWrap;text:"Current conditions, hourly outlook and a seven-day forecast for a place you choose.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        SettingsToggle {controlId:"weatherEnabled";visible:page.shows(controlId);objectName:"weatherEnabled";width:parent.width;label:"Enable weather";checked:SettingsStore.weatherEnabled;onToggled:function(value){SettingsStore.setWeatherPreferences({enabled:value})}}
        SettingsSection {
            id:locationGroup;sectionId:"weather.location";title:"Location";description:"Search for a city, state, country, postal code or address."
            searchQuery:page.query;controlIds:["weatherLocation"]
            Text {width:parent.width;visible:WeatherService.location!==null;text:WeatherService.location ? "Selected: "+WeatherService.location.name : "";textFormat:Text.PlainText;wrapMode:Text.WordWrap;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
            Row {
                property string controlId:"weatherLocation"
                width:parent.width;spacing:8
                Rectangle {
                    width:Math.max(120,parent.width-searchButton.width-8);height:34;radius:Theme.controlRadius;color:Theme.settingsHover;border.width:locationInput.activeFocus ? 1 : 0;border.color:Theme.controlAccent
                    Text {anchors.fill:parent;anchors.leftMargin:10;verticalAlignment:Text.AlignVCenter;visible:locationInput.text==="";text:"City, postal code or address";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize}
                    TextInput {id:locationInput;objectName:"weatherLocationSearch";anchors.fill:parent;anchors.leftMargin:10;anchors.rightMargin:10;verticalAlignment:TextInput.AlignVCenter;clip:true;selectByMouse:true;activeFocusOnTab:true;maximumLength:200;text:SettingsStore.weatherQuery;color:Theme.settingsText;selectionColor:Theme.settingsSelected;selectedTextColor:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;Accessible.name:"City, postal code or address";onAccepted:page.submitLocation()}
                }
                FlatButton {id:searchButton;objectName:"weatherSearchButton";height:34;label:WeatherService.busy && WeatherService.action==="search" ? "Searching…" : "Search";enabled:!WeatherService.busy && locationInput.text.trim().length>=2;onActivated:page.submitLocation()}
            }
            Repeater {
                model:WeatherService.searchResults
                delegate:FlatButton {
                    required property var modelData
                    objectName:"weatherChooseLocation";width:parent.width;height:42;navigation:true;label:modelData.name
                    Accessible.name:"Use "+modelData.name
                    onActivated:WeatherService.choose(modelData)
                }
            }
            Text {visible:WeatherService.searchAttribution!=="";width:parent.width;text:WeatherService.searchAttribution;wrapMode:Text.WordWrap;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"Search sends the place you enter to Open-Meteo. Addresses may also be searched with OpenStreetMap. Searches run only when you choose Search.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            FlatButton {objectName:"weatherApproximate";label:SettingsStore.weatherLocationMode==="automatic" ? "Update approximate location" : "Use approximate location";enabled:!WeatherService.busy;onActivated:WeatherService.locate()}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"Approximate location uses your public IP address through ipwho.is when you choose this option. It does not use GPS or run automatically in the background.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        SettingsSection {
            sectionId:"weather.forecast";title:"Forecast";description:"Choose units and how often weather is updated."
            searchQuery:page.query;controlIds:["weatherUnits","weatherRefresh"]
            ChoiceBox {property string controlId:"weatherUnits";visible:page.shows(controlId);objectName:"weatherUnits";width:parent.width;choices:[{label:"Celsius · km/h · millimetres",value:"metric"},{label:"Fahrenheit · mph · inches",value:"imperial"}];selectedValue:SettingsStore.weatherUnits;Accessible.name:"Weather units";onChosen:function(value){SettingsStore.setWeatherPreferences({units:value})}}
            ChoiceBox {property string controlId:"weatherRefresh";visible:page.shows(controlId);objectName:"weatherInterval";width:parent.width;choices:[{label:"Every 15 minutes",value:15},{label:"Every 30 minutes",value:30},{label:"Every hour",value:60},{label:"Every 2 hours",value:120}];selectedValue:SettingsStore.weatherRefreshMinutes;Accessible.name:"Weather refresh interval";onChosen:function(value){SettingsStore.setWeatherPreferences({refreshMinutes:value})}}
            FlatButton {objectName:"weatherRefreshNow";label:WeatherService.busy ? "Updating…" : "Refresh now";enabled:SettingsStore.weatherEnabled && WeatherService.configured && !WeatherService.busy;onActivated:WeatherService.refresh(true)}
            Text {width:parent.width;wrapMode:Text.WordWrap;visible:WeatherService.forecast!==null;text:WeatherService.updated+(WeatherService.forecast && WeatherService.forecast.stale ? " · showing the saved forecast" : "");color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
            Text {width:parent.width;wrapMode:Text.WordWrap;text:"Forecasts are cached on this device for offline use. Saved forecasts show their age. Weather is provided by Open-Meteo; air quality estimates by CAMS.";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
        }
        Text {width:parent.width;wrapMode:Text.WordWrap;visible:WeatherService.error!=="" || WeatherService.message!=="";text:WeatherService.error || WeatherService.message;textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    }
}
