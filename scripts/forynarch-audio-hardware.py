#!/usr/bin/env python3
"""User-session audio card profiles; no system service or privilege escalation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

def command(arguments):
    return subprocess.check_output(arguments,text=True,stderr=subprocess.PIPE,timeout=6)

def cards():
    raw=json.loads(command(["pactl","--format=json","list","cards"]))
    if not isinstance(raw,list):raise ValueError("Invalid audio card inventory")
    result=[]
    for card in raw[:64]:
        profiles=card.get("profiles",{})
        if isinstance(profiles,dict):profiles=[dict(value,name=key) for key,value in profiles.items()]
        active=card.get("active_profile","")
        if isinstance(active,dict):active=active.get("name","")
        result.append({"name":card["name"],"description":card.get("properties",{}).get("device.description",card["name"]),
            "active":active,"enabled":active!="off","profiles":[{"name":p["name"],"label":p.get("description",p["name"]),
                "available":p.get("available") not in (False,"no","not available"),"priority":p.get("priority",0)} for p in profiles]})
    return result

def state_path():
    return Path(os.environ.get("XDG_STATE_HOME",str(Path.home()/".local/state")))/"forynarch/audio-profiles.json"

def load_state():
    try:
        path=state_path()
        if path.stat().st_size>65536:return {}
        value=json.loads(path.read_text())
        return {name:profile for name,profile in value.items() if isinstance(name,str) and isinstance(profile,str) and len(name)<=512 and len(profile)<=512} if isinstance(value,dict) else {}
    except (OSError,ValueError):return {}

def save_state(value):
    path=state_path();path.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w",dir=path.parent,prefix=".audio-",delete=False) as stream:
        json.dump(value,stream);pending=stream.name
    os.replace(pending,path)

def set_profile(payload,inventory):
    if not isinstance(payload,dict) or set(payload)!={"card","profile"} or not all(isinstance(v,str) and len(v)<=512 and "\0" not in v for v in payload.values()):
        raise ValueError("Invalid audio hardware request")
    matching=[card for card in inventory if card["name"]==payload["card"]]
    if len(matching)!=1:raise ValueError("The audio device disconnected. Refresh and try again.")
    card=matching[0];profile=payload["profile"];previous=load_state()
    available={p["name"]:p for p in card["profiles"] if p["available"]}
    if profile=="restore":
        profile=previous.get(card["name"])
        if profile not in available or profile=="off":
            choices=sorted((p for p in available.values() if p["name"]!="off"),key=lambda p:p["priority"],reverse=True)
            if not choices:raise ValueError("No enabled profile is available. Reconnect this device.")
            profile=choices[0]["name"]
    if profile not in available:raise ValueError("This audio profile is unavailable. Choose another profile.")
    command(["pactl","set-card-profile",card["name"],profile])
    if profile=="off" and card["active"]!="off":previous[card["name"]]=card["active"]
    elif profile!="off":previous[card["name"]]=profile
    try:save_state(dict(list(previous.items())[-64:]))
    except OSError:pass

def main():
    if sys.argv[1:] not in (["status"],["set-profile"]):raise ValueError("Choose status or set-profile.")
    if sys.argv[1]=="set-profile":
        raw=sys.stdin.read(8193)
        if len(raw)>8192:raise ValueError("The audio hardware request is too large.")
        set_profile(json.loads(raw),cards())
    try:print(json.dumps({"available":True,"cards":cards()}))
    except (OSError,ValueError,subprocess.SubprocessError):
        if sys.argv[1]!="status":raise
        print(json.dumps({"available":False,"cards":[],"message":"Audio hardware is unavailable. Check the audio service or reconnect the device."}))

if __name__=="__main__":
    try:main()
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError) as error:
        print(json.dumps({"error":str(error) if isinstance(error,ValueError) else "The audio profile could not be changed."}),file=sys.stderr)
        raise SystemExit(1)
