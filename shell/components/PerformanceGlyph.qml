import QtQuick
Canvas {
    id:root
    antialiasing:true
    smooth:true
    property string kind:"cpu"
    property color foreground:"white"
    implicitWidth:16
    implicitHeight:16
    onKindChanged:requestPaint()
    onForegroundChanged:requestPaint()
    onWidthChanged:requestPaint()
    onHeightChanged:requestPaint()
    onPaint: {
        const c=getContext("2d")
        c.reset();c.scale(width/20,height/20)
        c.strokeStyle=foreground;c.lineWidth=1.35;c.lineCap="round";c.lineJoin="round"
        if(kind==="cpu") {
            c.strokeRect(5,5,10,10);c.strokeRect(8,8,4,4)
            c.beginPath()
            for(let i=7;i<=13;i+=3){c.moveTo(i,2);c.lineTo(i,5);c.moveTo(i,15);c.lineTo(i,18);c.moveTo(2,i);c.lineTo(5,i);c.moveTo(15,i);c.lineTo(18,i)}
            c.stroke()
        } else if(kind==="gpu") {
            c.strokeRect(2,5,15,10)
            c.beginPath();c.moveTo(17,4);c.lineTo(18.5,4);c.lineTo(18.5,16);c.moveTo(5,15);c.lineTo(5,17);c.lineTo(12,17);c.lineTo(12,15);c.stroke()
            c.beginPath();c.arc(8,10,3,0,Math.PI*2);c.moveTo(8,8);c.lineTo(8,12);c.moveTo(6,10);c.lineTo(10,10);c.moveTo(13,8);c.lineTo(14.5,8);c.moveTo(13,11);c.lineTo(14.5,11);c.stroke()
        } else {
            c.strokeRect(2,6,16,8)
            c.strokeRect(5,8.5,3,3);c.strokeRect(11,8.5,3,3)
            c.beginPath();for(let i=4;i<=16;i+=3){c.moveTo(i,14);c.lineTo(i,16)}c.stroke()
        }
    }
}
