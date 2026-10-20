#!/usr/bin/env python3
"""Validate owner-provided optional packages before the installer writes a disk."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

LOCAL_NAMES={"mudilmusic"}


def selections(plan):
    names=plan.get("explicit_optional_packages",[])
    if not isinstance(names,list) or any(not isinstance(name,str) or not re.fullmatch(r"[a-z0-9][a-z0-9@._+\-]*",name) for name in names):
        raise ValueError("The optional application selection is invalid.")
    local=sorted(set(names)&LOCAL_NAMES)
    if any(name not in plan.get("selected_group_ids",[]) for name in local):
        raise ValueError("The local application was not explicitly selected.")
    return local,sorted(set(names)-LOCAL_NAMES)


def inspect_package(path,name,version):
    members=subprocess.check_output(["bsdtar","-tf",str(path)],text=True,timeout=15).splitlines()
    if len(members)>10000:raise ValueError("The optional application archive has too many files.")
    allowed_dirs={"opt","opt/mudilmusic","usr","usr/bin","usr/share","usr/share/applications","usr/share/icons",
                  "usr/share/icons/hicolor","usr/share/icons/hicolor/512x512","usr/share/icons/hicolor/512x512/apps"}
    allowed_files={".PKGINFO",".BUILDINFO",".MTREE","usr/bin/mudilmusic","usr/share/applications/mudilmusic.desktop",
                   "usr/share/icons/hicolor/512x512/apps/mudilmusic.png"}
    for member in members:
        member=member.removeprefix("./").rstrip("/")
        parts=PurePosixPath(member)
        if parts.is_absolute() or ".." in parts.parts or not (member in allowed_dirs or member in allowed_files or member.startswith("opt/mudilmusic/")):
            raise ValueError("The optional application contains an unreviewed install path or script.")
    metadata=subprocess.check_output(["bsdtar","-xOf",str(path),".PKGINFO"],text=True,timeout=10)
    fields={}
    for line in metadata.splitlines():
        key,separator,value=line.partition(" = ")
        if separator:fields.setdefault(key,[]).append(value)
    if fields.get("pkgname")!=[name] or fields.get("pkgver")!=[version] or fields.get("arch")!=["x86_64"]:
        raise ValueError("The optional application metadata differs from the reviewed package.")


def verified_packages(bundle,plan):
    local,_=selections(plan)
    if not local:return []
    bundle=Path(bundle).resolve(strict=True)
    manifest_path=bundle/"local-applications.json"
    if not manifest_path.is_file() or manifest_path.stat().st_size>65536:
        raise ValueError("The selected optional application is not bundled in this ISO.")
    manifest=json.loads(manifest_path.read_text())
    if not isinstance(manifest,dict) or set(manifest)!={"schema_version","kind","packages"} or manifest["schema_version"]!=1 or manifest["kind"]!="bundled-optional-applications":
        raise ValueError("The optional application manifest is invalid.")
    packages=manifest["packages"]
    if not isinstance(packages,dict) or not set(packages).issubset(LOCAL_NAMES):
        raise ValueError("The optional application manifest contains an unknown package.")
    directory=bundle/"optional"
    if directory.is_symlink() or not directory.is_dir():raise ValueError("The optional package directory is invalid.")
    result=[]
    for name in local:
        record=packages.get(name)
        if not isinstance(record,dict) or set(record)!={"filename","sha256","version"}:
            raise ValueError("The selected optional application has no reviewed package.")
        filename=record["filename"];digest=record["sha256"];version=record["version"]
        if (not isinstance(filename,str) or not re.fullmatch(r"mudilmusic-[A-Za-z0-9._+\-]+-x86_64\.pkg\.tar\.zst",filename)
                or not isinstance(digest,str) or not re.fullmatch(r"[a-f0-9]{64}",digest)
                or not isinstance(version,str) or not re.fullmatch(r"[0-9][A-Za-z0-9.+_:\-]*",version)):
            raise ValueError("The optional application manifest has invalid package fields.")
        path=directory/filename
        if path.is_symlink() or not path.is_file() or path.resolve().parent!=directory.resolve():
            raise ValueError("The selected optional package is missing or unsafe.")
        hasher=hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda:stream.read(1024*1024),b""):hasher.update(chunk)
        if hasher.hexdigest()!=digest:raise ValueError("The optional application checksum does not match.")
        inspect_package(path,name,version)
        result.append({"name":name,"version":version,"filename":filename,"path":str(path),"bytes":path.stat().st_size})
    return result


def main(args):
    if len(args)!=3 or args[0] not in {"repo","names","files","inventory"}:raise ValueError("Choose a local application verification action.")
    mode,bundle,selection=args
    plan=json.loads(Path(selection).read_text())
    local,repo=selections(plan)
    if mode=="repo":return "\n".join(repo)
    if mode=="names":return "\n".join(local)
    packages=verified_packages(bundle,plan)
    if mode=="files":return "\n".join(record["path"] for record in packages)
    return "\n".join(f'{record["name"]} {record["version"]} {record["bytes"]}' for record in packages)


if __name__=="__main__":
    try:
        output=main(sys.argv[1:])
        if output:print(output)
    except (ValueError,OSError,subprocess.SubprocessError) as error:
        print(str(error) if isinstance(error,ValueError) else "The optional application package could not be verified.",file=sys.stderr)
        sys.exit(2)
