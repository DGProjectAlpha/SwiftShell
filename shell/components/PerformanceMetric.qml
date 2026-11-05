import QtQuick
import "../themes"
Item {
    id:root
    required property string label
    property string value:"—"
    property string detail:""
    property string temperature:""
    property var history:[]
    implicitWidth:320
    implicitHeight:100
    Text {id:heading;x:0;y:0;text:root.label;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize;font.weight:Font.Medium}
    Text {anchors.right:parent.right;y:0;text:root.value;color:Theme.settingsText;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSize+2;font.weight:Font.Medium}
    Text {x:0;y:26;width:parent.width*.65;text:root.detail;elide:Text.ElideRight;textFormat:Text.PlainText;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    Text {anchors.right:parent.right;y:26;text:root.temperature;color:Theme.settingsMuted;font.family:Theme.settingsFontFamily;font.pixelSize:Theme.settingsFontSizeSmall}
    Canvas {
        id:graph
        y:51;width:parent.width;height:42
        property color stroke:Theme.settingsText
        onStrokeChanged:requestPaint()
        onWidthChanged:requestPaint()
        Connections {target:root;function onHistoryChanged(){graph.requestPaint()}}
        onPaint: {
            const c=getContext("2d");c.reset()
            c.strokeStyle=Theme.settingsMuted;c.globalAlpha=.16;c.lineWidth=1
            for(let i=0;i<3;i++){const y=1+(height-2)*i/2;c.beginPath();c.moveTo(0,y);c.lineTo(width,y);c.stroke()}
            if(root.history.length<2)return
            c.globalAlpha=.9;c.strokeStyle=stroke;c.lineWidth=1.5;c.lineJoin="round"
            c.beginPath()
            const step=width/59,offset=width-(root.history.length-1)*step
            for(let i=0;i<root.history.length;i++) {
                const x=offset+i*step,y=height-1-(height-2)*root.history[i]/100
                if(i===0)c.moveTo(x,y);else c.lineTo(x,y)
            }
            c.stroke()
        }
    }
}
