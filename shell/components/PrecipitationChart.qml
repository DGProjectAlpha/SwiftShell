import QtQuick
import QtQuick.Controls.Basic as Controls
import "../logic/weather.js" as Weather
import "../themes"
Item {
    id:root
    property var hours:[]
    property string mode:"probability"
    property string unit:"mm"
    readonly property real maximum:Weather.chartMaximum(hours,mode)
    readonly property bool hasData:hours.some(function(hour){return Weather.number(root.mode==="probability" ? hour.probability : hour.precipitation)})
    implicitWidth:360;implicitHeight:102
    onHoursChanged:chart.requestPaint()
    onModeChanged:chart.requestPaint()
    Canvas {
        id:chart;x:0;y:12;width:parent.width;height:66
        property color foreground:Theme.settingsText
        property color baselineColor:Theme.settingsSelected
        onForegroundChanged:requestPaint()
        onBaselineColorChanged:requestPaint()
        onWidthChanged:requestPaint()
        onPaint: {
            const c=getContext("2d");c.reset();c.fillStyle=baselineColor;c.fillRect(0,height-1,width,1)
            const count=root.hours.length,step=width/Math.max(1,count)
            c.fillStyle=foreground
            for(let i=0;i<count;i++){
                const value=root.mode==="probability" ? root.hours[i].probability : root.hours[i].precipitation
                if(!Weather.number(value))continue
                const h=Math.max(0,Math.min(height-8,value/root.maximum*(height-8)))
                c.globalAlpha=.5+(i%3)*.12;c.fillRect(i*step+step*.17,height-h,Math.max(1,step*.66),h)
            }
            c.globalAlpha=1
        }
    }
    Text {anchors.top:parent.top;anchors.right:parent.right;text:root.mode==="probability" ? "100%" : Weather.amount(root.maximum,root.unit);color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    Row {
        y:82;width:parent.width
        Repeater {
            model:Math.min(4,root.hours.length)
            delegate:Text {
                required property int index
                width:root.width/Math.max(1,Math.min(4,root.hours.length))
                readonly property int hourIndex:Math.round(index*(root.hours.length-1)/Math.max(1,Math.min(4,root.hours.length)-1))
                text:root.hours[hourIndex] ? root.hours[hourIndex].label : ""
                horizontalAlignment:index===0 ? Text.AlignLeft : index===Math.min(4,root.hours.length)-1 ? Text.AlignRight : Text.AlignHCenter
                color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall
            }
        }
    }
    Text {anchors.centerIn:chart;visible:!root.hasData;text:"Precipitation data unavailable";color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    MouseArea {
        id:pointer;anchors.fill:chart;hoverEnabled:true;acceptedButtons:Qt.NoButton
        property int index:Math.min(root.hours.length-1,Math.max(0,Math.floor(mouseX/Math.max(1,width)*root.hours.length)))
        Controls.ToolTip.visible:containsMouse && root.hours.length>0
        Controls.ToolTip.text:root.hours[index] ? root.hours[index].label+" · "+(root.mode==="probability" ? Weather.percent(root.hours[index].probability) : Weather.amount(root.hours[index].precipitation,root.unit)) : ""
    }
}
