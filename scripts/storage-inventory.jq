# Read-only view model. START is the kernel's count of 512-byte sectors.
def mounts: [.mountpoints[]? | select(.!=null and .!="")];
def reserved:
  ((.parttype//""|ascii_downcase) as $t |
   ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b","e3c9e316-0b5c-4db8-817d-f92df00215ae",
    "de94bba4-06d1-4d40-a16a-bfd50179d6ac","0xef","0x27"]|index($t))!=null;
def system_mount:
  any(mounts[]; .=="/" or .=="/boot" or .=="/boot/efi" or .=="/efi" or startswith("/run/archiso") or .=="[SWAP]");
def partition:
  . as $p |
  {id:(if (.partuuid//"")!="" then "partuuid:"+(.partuuid|ascii_downcase) elif (.uuid//"")!="" then "uuid:"+(.uuid|ascii_downcase) else "path:"+.path end),
   path:.path,name:(.label//.partlabel//.name),filesystem:(.fstype//"Unknown"),size:(.size|tonumber),
   start:((.start//0|tonumber)*512),partitionType:(.parttype//""|ascii_downcase),partitionUuid:(.partuuid//""|ascii_downcase),mountpoints:mounts,mounted:((mounts|length)>0),
   readOnly:(.ro==true or .ro==1),protected:(reserved or system_mount),
   encrypted:((.fstype//""|ascii_downcase) as $f | ["bitlocker","crypto_luks"]|index($f)!=null),
   role:(if reserved then "Boot / reserved / recovery" elif system_mount then "Current system" elif (.fstype//""|ascii_downcase)=="ntfs" then "Windows-compatible data" else "Data partition" end)};
def disk:
  ([recurse(.children[]?)|select(.type=="part")|partition]|sort_by(.start)) as $parts |
  {id:(if (.wwn//"")!="" then "wwn:"+.wwn elif (.serial//"")!="" then "serial:"+(.model//"")+":"+.serial elif (.ptuuid//"")!="" then "table:"+.ptuuid else "path:"+.path end),
   path:.path,name:(if (.model//""|gsub("^ +| +$";""))!="" then (.model|gsub("^ +| +$";"")) else .name end),
   size:(.size|tonumber),table:(if .pttype then (.pttype|ascii_downcase) else "Unknown" end),transport:(.tran//"Unknown"),
   logicalSectorSize:(.["log-sec"]//512|tonumber),
   readOnly:(.ro==true or .ro==1),containsSystem:any(recurse(.children[]?);system_mount),
   wholeFilesystem:((.fstype//"")!=""),partitions:$parts,
   windowsCandidate:any($parts[]; .filesystem=="ntfs" or .encrypted),
   hasEfi:any(recurse(.children[]?);(.parttype//""|ascii_downcase)=="c12a7328-f81f-11d2-ba4b-00a0c93ec93b")}
  | . as $d | ((16384 / .logicalSectorSize|ceil)+1)*.logicalSectorSize as $backupBytes
  | .firstUsableEstimate=($backupBytes+.logicalSectorSize)
  | .lastUsableEstimate=(.size-$backupBytes)
  | . as $d | .geometryKnown=(.table=="gpt" and .size>2097152 and (.wholeFilesystem|not) and
      all($parts[]; .start>=$d.firstUsableEstimate and .size>0 and (.start+.size)<=$d.lastUsableEstimate and
          (.start % $d.logicalSectorSize)==0 and (.size % $d.logicalSectorSize)==0) and
      (reduce $parts[] as $p ({end:$d.firstUsableEstimate,valid:true}; .valid=(.valid and $p.start>=.end)|.end=$p.start+$p.size)|.valid))
  | .gaps=(if .geometryKnown then
      (reduce ($parts+[{start:$d.lastUsableEstimate,size:0}])[] as $p
       ({end:$d.firstUsableEstimate,gaps:[]}; if $p.start>.end then .gaps+=[{start:.end,size:($p.start-.end)}] else . end | .end=$p.start+$p.size)|.gaps)
    else [] end)
  | .unallocatedEstimate=([.gaps[].size]|add//0);
[.blockdevices[]|select(.type=="disk")|disk] as $disks |
{version:1,live:$live,uefi:$uefi,executionSupported:false,disks:[$disks[]|. as $d|.stableIdentity=((.id|startswith("path:")|not) and ([$disks[]|select(.id==$d.id)]|length)==1)]}
