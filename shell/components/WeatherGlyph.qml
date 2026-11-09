import QtQuick
import "../logic/weather.js" as Weather
Canvas {
    id:glyph
    antialiasing:true
    smooth:true
    property var code:null
    property bool daylight:true
    property color foreground:"white"
    implicitWidth:24;implicitHeight:24
    onCodeChanged:requestPaint()
    onDaylightChanged:requestPaint()
    onForegroundChanged:requestPaint()
    onWidthChanged:requestPaint()
    onHeightChanged:requestPaint()
    onPaint: {
        const c=getContext("2d");c.reset();c.scale(width/32,height/32);c.strokeStyle=foreground;c.fillStyle=foreground;c.lineWidth=1.6;c.lineCap="round";c.lineJoin="round"
        const kind=Weather.icon(code)
        function sun(x,y,r){c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.stroke();for(let i=0;i<8;i++){const a=i*Math.PI/4;c.beginPath();c.moveTo(x+Math.cos(a)*(r+2),y+Math.sin(a)*(r+2));c.lineTo(x+Math.cos(a)*(r+4),y+Math.sin(a)*(r+4));c.stroke()}}
        function moon(){c.beginPath();c.arc(16,15,8,.35*Math.PI,1.75*Math.PI);c.quadraticCurveTo(10,14,16+8*Math.cos(.35*Math.PI),15+8*Math.sin(.35*Math.PI));c.stroke()}
        function cloud(){c.beginPath();c.moveTo(8,22);c.bezierCurveTo(2,22,2,14,8,14);c.bezierCurveTo(8,6,20,5,22,13);c.bezierCurveTo(30,11,32,22,25,22);c.closePath();c.stroke()}
        if(kind==="clear"){if(daylight)sun(16,15,6);else moon();return}
        if(kind==="partly"){sun(10,9,4);cloud();return}
        if(kind==="unknown"){c.beginPath();c.arc(16,15,8,0,Math.PI*2);c.stroke();c.font="16px sans-serif";c.textAlign="center";c.fillText("?",16,21);return}
        cloud()
        if(kind==="rain"){for(let x=10;x<=24;x+=7){c.beginPath();c.moveTo(x,25);c.lineTo(x-2,29);c.stroke()}}
        if(kind==="snow"){for(let x=10;x<=24;x+=7){c.beginPath();c.moveTo(x,25);c.lineTo(x,30);c.moveTo(x-2,26);c.lineTo(x+2,29);c.moveTo(x+2,26);c.lineTo(x-2,29);c.stroke()}}
        if(kind==="storm"){c.beginPath();c.moveTo(17,22);c.lineTo(13,27);c.lineTo(18,27);c.lineTo(15,31);c.stroke()}
        if(kind==="fog"){c.beginPath();c.moveTo(6,26);c.lineTo(26,26);c.moveTo(10,30);c.lineTo(23,30);c.stroke()}
    }
}
