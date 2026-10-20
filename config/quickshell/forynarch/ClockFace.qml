import QtQuick
import "WidgetPalette.js" as Palette

Canvas {
    id: clock
    property date time: new Date()
    property color accent: "#9acbff"
readonly property string minuteKey: Qt.formatDateTime(time,"yyyyMMddhhmm")
onMinuteKeyChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c=getContext("2d"); c.reset(); c.translate(width/2,height/2);
        const r=Math.min(width,height)/2-5;
        c.beginPath();
        for(let i=0;i<=360;i++){
            const a=i*Math.PI/180, radius=r-5+5*Math.cos(a*12);
            if(i===0)c.moveTo(Math.cos(a)*radius,Math.sin(a)*radius);
            else c.lineTo(Math.cos(a)*radius,Math.sin(a)*radius);
        }
c.closePath();
const face=c.createLinearGradient(-r,-r,r,r);
face.addColorStop(0,"#243e57");face.addColorStop(1,"#112031");
c.fillStyle=face;c.fill();c.strokeStyle=Palette.edge;c.lineWidth=1;c.stroke();
c.font="bold "+Math.round(r*.42)+"px sans-serif";c.textAlign="center";c.fillStyle=Palette.muted;
        for(let h of [12,3,6,9]){const a=h*Math.PI/6;c.fillText(String(h),Math.sin(a)*r*.6,-Math.cos(a)*r*.6+r*.14);}
        function hand(angle,length,thickness,color){c.beginPath();c.lineWidth=thickness;c.strokeStyle=color;c.lineCap="round";c.moveTo(0,0);c.lineTo(Math.sin(angle)*length,-Math.cos(angle)*length);c.stroke();}
hand((time.getHours()%12+time.getMinutes()/60)*Math.PI/6,r*.43,9,Palette.primary);
        hand(time.getMinutes()*Math.PI/30,r*.68,7,accent);
        c.beginPath();c.arc(0,0,6,0,Math.PI*2);c.fillStyle="#102338";c.fill();
    }
}
