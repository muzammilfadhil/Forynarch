import QtQuick
import Quickshell
import Quickshell.Networking
import "."
import "WifiStatus.js" as WifiStatus

ShellRoot {
    QtObject{id:controller;property bool controlOpen:false}
    QtObject{id:network;property bool connected:false;property string name:"Forynarch Wi-Fi"}
    QtObject{id:adapter;property int type:DeviceType.Wifi;property bool connected:false;property QtObject networks:QtObject{property var values:[network]}}
    QtObject{id:service;property bool wifiEnabled:true;property bool wifiHardwareEnabled:true;property QtObject devices:QtObject{property var values:[adapter]}}
    QuickControlActions{id:actions;controller:controller;networkService:service}
    function check(condition,message){if(!condition)throw new Error(message);}
    Timer{
        interval:100;running:true
        onTriggered:{
            try{
                const snapshot=WifiStatus.device("enp0s3:ethernet:connected:Wired connection\nwlan0:wifi:connected:Work\\: main\\\\profile\n");
                check(snapshot.connected&&snapshot.name==="wlan0"&&snapshot.connection==="Work: main\\profile","Escaped connection names or wired priority broke Wi-Fi status");
                actions.wifiDeviceState=snapshot;
                actions.wifiAccessPointText="wlan0:*:Cafe\\: Blue\\\\sky\nwlan1:*:Other\n";
                check(actions.wifiConnected&&actions.wifiName==="Cafe: Blue\\sky","Connected SSID missing when scan model has no active AP");
                network.connected=true;
                check(actions.wifiName==="Forynarch Wi-Fi","Live network property did not update the binding: "+actions.wifiName+" adapters="+actions.wifiAdapters.length+" connected="+network.connected);
                network.connected=false;
                service.wifiEnabled=false;
                check(actions.wifiName==="Off","Radio-off state showed a cached SSID");
                service.wifiEnabled=true;
                actions.wifiDeviceState=WifiStatus.device("wlan0:wifi:connecting (prepare):--\n");
                check(!actions.wifiConnected&&actions.wifiName==="Connecting…","Connecting state lost");
                actions.wifiDeviceState=WifiStatus.device("wlan0:wifi:disconnected:--\n");
                check(!actions.wifiConnected&&actions.wifiName==="Not Connected","Disconnected state showed a stale access point");
                actions.wifiDeviceState=null;adapter.connected=true;
                check(actions.wifiConnected,"Backend fallback lost connected device state");
                check(!WifiStatus.device("").available,"Missing adapter was reported as disconnected hardware");
                console.log("PASS Wi-Fi escaped SSIDs, wired coexistence, reactive connection, radio, connecting, disconnect and service fallback");
                Qt.quit();
            }catch(error){console.error("FAIL "+error);Qt.exit(1);}
        }
    }
}
