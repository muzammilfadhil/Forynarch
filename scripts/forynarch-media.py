#!/usr/bin/env python3
"""Fetch lyrics only when the user enables their music widget's lyrics view."""
import json
import hashlib
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from difflib import SequenceMatcher
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener


class LyricsRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        target=urlparse(newurl)
        if target.scheme!="https" or target.netloc!="lrclib.net":
            raise URLError("Unexpected lyrics redirect")
        return super().redirect_request(request,fp,code,msg,headers,newurl)


def parse_lyrics(value):
    if not isinstance(value,str):return []
    result=[]
    offset=re.search(r"\[offset:([+-]?\d+)\]",value,re.I)
    adjustment=int(offset[1])/1000 if offset else 0
    for line in value.splitlines()[:2000]:
        stamps=list(re.finditer(r"\[(\d{1,3}):(\d{2}(?:\.\d+)?)\]",line))
        if stamps:
            text=re.sub(r"\[[^]]*\]","",line).strip()[:1000]
            result.extend({"t":max(0,int(stamp[1])*60+float(stamp[2])-adjustment),"text":text} for stamp in stamps[:8])
        elif line.strip() and not re.match(r"^\[[a-z]+:",line,re.I):
            result.append({"t":-1,"text":line.strip()[:1000]})
    timed=[row for row in result if row["t"]>=0]
    return sorted(timed,key=lambda row:row["t"]) if timed else result


def request_json(endpoint,parameters):
    request=Request("https://lrclib.net/api/"+endpoint+"?"+urlencode(parameters),
                    headers={"User-Agent":"ForynarchMusicWidget/1.0","Accept":"application/json"})
    with build_opener(LyricsRedirect()).open(request,timeout=6) as response:
        raw=response.read(1024*1024+1)
    if len(raw)>1024*1024:raise ValueError("Lyrics response is too large")
    return json.loads(raw)


def clean_metadata(title, artist):
    suffix = r"[\[(](?:official(?:\s+music)?\s*(?:video|audio)?|lyrics?|music\s+video|audio|video|hd|4k)[\]) ]*"
    title = re.sub(suffix, "", title, flags=re.I).strip()
    artist = re.sub(r"VEVO$", "", artist, flags=re.I).strip()
    if " - " in title:
        prefix, track = title.split(" - ", 1)
        if not artist or prefix.casefold() == artist.casefold():
            artist, title = prefix.strip(), track.strip()
    return title, artist

def lyrics(title,artist,album,duration):
    if not title.strip():return {"state":"none","lines":[],"synced":False}
    if any(len(value)>1000 for value in (title,artist,album)):
        raise ValueError("Track metadata is too long")
    title,artist=clean_metadata(title,artist)
    if not title:return {"state":"none","lines":[],"synced":False}
    duration=float(duration)
    if not math.isfinite(duration):raise ValueError("Invalid track duration")
    duration=max(0,min(86400,duration))
    parameters={"track_name":title,"artist_name":artist}
    if album and not album.lower().startswith("mudil"):parameters["album_name"]=album
    if duration:parameters["duration"]=round(duration)
    candidate=None
    try:
        if artist:candidate=request_json("get",parameters)
    except HTTPError as error:
        if error.code!=404:raise
    if isinstance(candidate,dict) and candidate.get("instrumental") is True:return {"state":"none","lines":[],"synced":False}
    if not isinstance(candidate,dict) or not (candidate.get("syncedLyrics") or candidate.get("plainLyrics")):
        matches=request_json("search",{"track_name":title,"artist_name":artist} if artist else {"q":title})
        if isinstance(matches,list):
            matches=[row for row in matches[:100] if isinstance(row,dict) and (row.get("syncedLyrics") or row.get("plainLyrics"))]
            if duration:matches=[row for row in matches if abs(float(row.get("duration") or 0)-duration)<=8]
            def similarity(row):
                name=str(row.get("trackName",title)).casefold()
                performer=str(row.get("artistName",artist)).casefold()
                return SequenceMatcher(None,title.casefold(),name).ratio(),SequenceMatcher(None,artist.casefold(),performer).ratio() if artist else 1
            matches=[row for row in matches if similarity(row)[0]>=.65 and similarity(row)[1]>=.5]
            matches.sort(key=lambda row:(-sum(similarity(row)),not bool(row.get("syncedLyrics")),abs(float(row.get("duration") or 0)-duration)))
            candidate=matches[0] if matches else None
    if not isinstance(candidate,dict):return {"state":"none","lines":[],"synced":False}
    lines=parse_lyrics(candidate.get("syncedLyrics") or candidate.get("plainLyrics") or "")
    return {"state":"ok" if lines else "none","lines":lines,"synced":bool(lines and lines[0]["t"]>=0)}


def cached_lyrics(title,artist,album,duration):
    if not title.strip():return {"state":"none","lines":[],"synced":False}
    if any(len(value)>1000 for value in (title,artist,album)):raise ValueError("Track metadata is too long")
    title,artist=clean_metadata(title,artist)
    key=hashlib.sha256(json.dumps([title,artist,album,str(duration)],ensure_ascii=False).encode()).hexdigest()
    folder=Path(os.environ.get("XDG_CACHE_HOME",str(Path.home()/".cache")))/"forynarch/lyrics"
    filename=folder/(key+".json")
    now=time.time()
    try:
        if filename.is_file() and not filename.is_symlink() and filename.stat().st_size<=1024*1024:
            entry=json.loads(filename.read_text())
            if entry["expires"]>now and entry["result"]["state"] in ("ok","none","unavailable") and isinstance(entry["result"]["lines"],list):
                return entry["result"]
    except (OSError,ValueError,KeyError,TypeError):pass
    try:result=lyrics(title,artist,album,duration)
    except (OSError,URLError,ValueError,TypeError):result={"state":"unavailable","lines":[],"synced":False}
    lifetime={"ok":30*86400,"none":6*3600,"unavailable":60}[result["state"]]
    try:
        folder.mkdir(parents=True,exist_ok=True)
        payload=json.dumps({"expires":now+lifetime,"result":result},ensure_ascii=False).encode()
        if len(payload)<=1024*1024:
            with tempfile.NamedTemporaryFile(dir=folder,prefix=".lyrics-",delete=False) as temporary:
                temporary.write(payload);pending=Path(temporary.name)
            os.replace(pending,filename)
        files=sorted((p for p in folder.glob("*.json") if re.fullmatch(r"[0-9a-f]{64}\.json",p.name) and not p.is_symlink()),key=lambda p:p.stat().st_mtime,reverse=True)
        total=0
        for index,path in enumerate(files):
            total+=path.stat().st_size
            if index>=64 or total>8*1024*1024:path.unlink()
    except OSError:pass
    return result

if __name__=="__main__":
    try:
        if len(sys.argv)!=6 or sys.argv[1]!="lyrics":raise ValueError("Choose a lyrics action")
        result=cached_lyrics(*sys.argv[2:])
    except (OSError,URLError,ValueError,TypeError,json.JSONDecodeError):
        result={"state":"unavailable","lines":[],"synced":False}
    print(json.dumps(result))
