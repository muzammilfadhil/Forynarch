# Proposal only. This model cannot produce commands or authorize disk writes.
($inventory[0]) as $i | ($catalog[0].groups) as $groups |
if ($request|type)!="object" then error("Invalid proposal") else . end |
($request.kind//"") as $kind |
if ($request.offline//false|type)!="boolean" then error("Invalid offline selection") else . end |
if (["create","resize","format","delete","install-alongside","install-erase","install-manual"]|index($kind))==null then error("Unknown proposal type") else . end |
($request.selectedGroups//[]) as $selected |
if ($selected|type)!="array" or any($selected[]; type!="string") or any($selected[]; . as $id|any($groups[];.id==$id)|not) then error("Unknown software selection") else . end |
([$i.disks[]|select(.id==$request.diskId)]) as $matches |
($matches[0]//{}) as $d |
([$d.partitions[]?|select(.id==($request.partitionId//""))]) as $partitions |
($partitions[0]//{}) as $p |
($request.sizeGiB//0) as $size |
if ($size|type)!="number" or $size<0 or $size>1048576 then error("Invalid size") else . end |
($size*1073741824|floor) as $bytes |
(["create","resize","format","delete"]|index($kind)!=null) as $partitionOperation |
(["resize","format","delete"]|index($kind)!=null) as $existingOperation |
([
  if $request.revision!=$i.revision then "Disk information changed. Refresh and review again." else empty end,
  if ($matches|length)!=1 then "Select one currently detected disk." else empty end,
  if ($d.stableIdentity//false|not) then "A unique stable disk identity must be verified." else empty end,
  if $d.readOnly then "The disk is read-only." else empty end,
  if $d.containsSystem and ($kind|startswith("install-")) then "The selected disk contains the running system, swap or Live media." else empty end,
  if $existingOperation and ($partitions|length)!=1 then "Select one existing partition." else empty end,
  if $existingOperation and ($p.protected or $p.mounted or $p.readOnly or $p.encrypted) then "Boot, recovery, mounted, encrypted and read-only partitions are protected." else empty end,
  if $existingOperation and ($p.id//""|startswith("path:")) then "The partition needs a stable UUID before an executable plan can be prepared." else empty end,
  if ($kind=="create" or $kind=="format") and (["ext4","btrfs","exfat","ntfs"]|index($request.filesystem))==null then "Select a supported filesystem." else empty end,
  if $kind=="create" and ($bytes<1073741824 or (any($d.gaps[]?; .size>=$bytes)|not)) then "Choose at least 1 GiB within an estimated unallocated region." else empty end,
  if $kind=="resize" then "Open Partition Manager for filesystem checks and resizing. This review does not resize filesystems." else empty end,
  if ($kind|startswith("install-")) and ($i.live|not) then "Boot the Forynarch Live media to install." else empty end,
  if ($kind|startswith("install-")) and ($i.uefi|not) then "Restart the Live USB in UEFI mode. A GPT disk alone does not make this a UEFI session." else empty end,
  if $kind=="install-erase" and $d.size<34359738368 then "A disk of at least 32 GiB is required." else empty end,
  if ($request.offline//false) and ($selected|length)>0 then "Optional software has no verified offline bundle. Choose core only for offline installation." else empty end,
  if ($partitionOperation) then "Apply partition changes in Partition Manager after reviewing its pending operations." else empty end
]) as $blockers |
{version:1,kind:$kind,canExecute:false,reviewOnly:true,revision:$i.revision,
 target:{disk:($d.path//"Not selected"),partition:($p.path//""),name:($d.name//"")},
 destructive:($kind=="format" or $kind=="delete" or $kind=="install-erase"),
 summary:(if $kind=="install-alongside" then "Install on the selected Linux root partition; preserve other operating systems and reuse EFI without formatting it."
 elif $kind=="install-erase" then "Erase the selected whole disk and install Forynarch. Existing files and operating systems would be deleted."
 elif $kind=="install-manual" then "Format the selected root partition as ext4 and preserve the selected EFI System Partition."
 else "Prepare a "+$kind+" operation for the selected disk or partition. No changes have been applied." end),
 requestedSizeGiB:$size,filesystem:($request.filesystem//""),
 selectedGroups:($selected|unique),optionalPackages:([$groups[]|select(.id as $id|$selected|index($id))|.packages[]]|unique),
 blockers:$blockers,
checks:(if $kind=="install-alongside" then ["Back up important files and keep any encryption recovery keys available.","Prepare unallocated space using tools appropriate for the existing operating system and filesystem.","Verify firmware mode, encryption, filesystem health, EFI space and preservation of existing boot entries.","Preserve existing operating-system, shared-data, reserved and recovery partitions."] else ["Verify disk identity, current mounts, filesystem health and backups.","Review every proposed create, resize, format, delete and bootloader change before final authorization."] end)}
