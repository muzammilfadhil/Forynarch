import QtQuick

Canvas {
    id: icon
    property string name: ""
    property color ink: "#d3dff0"
    property int size: 20
    implicitWidth: size; implicitHeight: size
    Image {
        anchors.fill: parent
        visible: icon.name === "forynarch"
        source: visible ? "file:///usr/share/forynarch/branding/logo.svg" : ""
        fillMode: Image.PreserveAspectFit
    }
    onNameChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"); c.reset(); c.scale(width / 24, height / 24);
        c.strokeStyle = ink; c.fillStyle = ink; c.lineWidth = 1.7;
        c.lineCap = "round"; c.lineJoin = "round";
        function line(points) { c.beginPath(); c.moveTo(points[0], points[1]); for (let i=2; i<points.length; i+=2) c.lineTo(points[i],points[i+1]); c.stroke(); }
        function circle(x,y,r) { c.beginPath(); c.arc(x,y,r,0,Math.PI*2); c.stroke(); }
        switch (name) {
        case "search": circle(10,10,6); line([15,15,21,21]); break;
        case "up": line([6,15,12,9,18,15]); break;
        case "down": line([6,9,12,15,18,9]); break;
        case "spark": line([12,3,14.5,9.5,21,12,14.5,14.5,12,21,9.5,14.5,3,12,9.5,9.5,12,3]); break;
        case "grid": for (let y of [4,14]) for (let x of [4,14]) c.strokeRect(x,y,6,6); break;
        case "displays": c.strokeRect(2,3,13,10); c.strokeRect(10,10,12,10); line([5,16,8,16]); line([16,20,16,23]); break;
        case "input": c.strokeRect(2,5,12,13); line([5,9,5,10]); line([8,9,8,10]); line([11,9,11,10]); line([5,14,11,14]); c.strokeRect(17,5,5,14); line([19.5,5,19.5,11]); break;
        case "shortcuts": c.strokeRect(3,3,7,7); c.strokeRect(14,3,7,7); line([6.5,5,6.5,8]); line([16,6.5,19,6.5]); line([5,20,5,15,19,15]); line([16,12,19,15,16,18]); break;
        case "camera": c.strokeRect(3,7,18,13); line([7,7,9,4,15,4,17,7]); circle(12,13,4); break;
        case "crop": line([7,2,7,17,22,17]); line([2,7,17,7,17,22]); break;
        case "clipboard": c.strokeRect(5,5,14,17); c.strokeRect(9,2,6,5); line([8,11,16,11]); line([8,15,16,15]); break;
        case "trash": line([4,6,20,6]); line([9,3,15,3]); line([6,6,7,21,17,21,18,6]); line([10,10,10,17]); line([14,10,14,17]); break;
        case "image": c.strokeRect(3,3,18,18); circle(8,8,2); line([3,17,10,11,14,15,17,12,21,17]); break;
        case "folder": line([3,7,3,20,21,20,21,7,12,7,10,4,3,4,3,7]); break;
        case "drive": line([5,4,19,4,22,14,22,20,2,20,2,14,5,4]);line([2,14,22,14]);circle(17,17,0.8);break;
        case "bluetooth": line([12,2,12,22,18,16,6,6,18,8,6,18,12,12]);break;
        case "ethernet": c.strokeRect(4,4,16,13);line([9,17,9,21,15,21,15,17]);for(let x of [7,10,13,16])line([x,6,x,9]);break;
        case "network-medium": for(let r of [4,8]) {c.beginPath();c.arc(12,19,r,-2.35,-.79);c.stroke();}circle(12,19,.6);break;
        case "network-weak": c.beginPath();c.arc(12,19,4,-2.35,-.79);c.stroke();circle(12,19,.6);break;
        case "terminal": c.strokeRect(3,4,18,16); line([6,8,10,12,6,16]); line([13,16,17,16]); break;
        case "control-center":
            for(const y of [7,17]){c.beginPath();c.moveTo(6,y-3);c.lineTo(18,y-3);c.arc(18,y,3,-Math.PI/2,Math.PI/2);c.lineTo(6,y+3);c.arc(6,y,3,Math.PI/2,3*Math.PI/2);c.closePath();c.stroke();}
            circle(8,7,1.5);circle(16,17,1.5);break;
        case "settings": circle(12,12,4); for(let i=0;i<8;i++){const a=i*Math.PI/4;line([12+Math.cos(a)*7,12+Math.sin(a)*7,12+Math.cos(a)*9,12+Math.sin(a)*9]);} circle(12,12,7); break;
        case "panel": c.strokeRect(3,4,18,16); line([3,9,21,9]); break;
        case "desktop": c.strokeRect(3,4,18,13); line([12,17,12,21,7,21,17,21]); break;
        case "palette": circle(12,12,9); for(let p of [[8,7],[14,6],[18,11],[7,13]]) circle(p[0],p[1],1); break;
        case "keyboard": c.strokeRect(2,6,20,13); for(let y of [10,13]) for(let x of [6,10,14,18]) line([x,y,x+.5,y]); line([7,16,17,16]); break;
        case "info": circle(12,12,9); line([12,11,12,17]); circle(12,7,.4); break;
        case "close": line([6,6,18,18]); line([18,6,6,18]); break;
            case "minimize":line([5,17,19,17]);break;
            case "maximize":c.strokeRect(5,5,14,14);break;
            case "restore":line([8,5,8,3,21,3,21,16,19,16]);c.strokeRect(3,8,13,13);break;
        case "check": line([5,12,10,17,19,7]); break;
        case "chevron": line([9,6,15,12,9,18]); break;
        case "chevron-up": line([6,15,12,9,18,15]); break;
        case "volume": line([3,9,7,9,12,5,12,19,7,15,3,15,3,9]); c.beginPath();c.arc(12,12,7,-.8,.8);c.stroke();c.beginPath();c.arc(12,12,10,-.8,.8);c.stroke(); break;
        case "mute": line([3,9,7,9,12,5,12,19,7,15,3,15,3,9]); line([16,9,22,15]); line([22,9,16,15]); break;
        case "network": for (let r of [4,8,12]) { c.beginPath();c.arc(12,19,r,-2.35,-.79);c.stroke(); } circle(12,19,.6); break;
        case "battery": c.strokeRect(2,6,18,12); line([22,10,22,14]); c.fillRect(5,9,10,6); break;
case "power": c.beginPath();c.arc(12,13,8,-1.05,4.2);c.stroke();line([12,3,12,12]);break;
        case "lock": c.strokeRect(5,10,14,11); c.beginPath();c.arc(12,10,4,Math.PI,0);c.stroke();line([12,14,12,17]);break;
        case "moon": c.beginPath();c.arc(12,12,9,.3,4.4);c.quadraticCurveTo(9,17,20.6,14.6);c.stroke();break;
        case "bell": c.beginPath();c.moveTo(5,17);c.lineTo(7,14);c.lineTo(7,9);c.arc(12,9,5,Math.PI,Math.PI*2);c.lineTo(17,14);c.lineTo(19,17);c.closePath();c.stroke();c.beginPath();c.arc(12,20,2,0,Math.PI);c.stroke();break;
        case "play": line([8,5,19,12,8,19,8,5]);break;
        case "pause": line([8,5,8,19]);line([16,5,16,19]);break;
        case "next": line([5,6,15,12,5,18,5,6]);line([19,6,19,18]);break;
        case "previous": line([19,6,9,12,19,18,19,6]);line([5,6,5,18]);break;
        case "music": line([9,18,9,5,20,3,20,16]);circle(6,18,3);circle(17,16,3);break;
        case "clock": circle(12,12,9);line([12,6,12,12,16,14]);break;
        }
    }
}
