# Read-only discovery. Never assign Windows letters by disk order or label.
def id:
  if (.partuuid // "") != "" then "partuuid:" + (.partuuid | ascii_downcase)
  elif (.uuid // "") != "" then "uuid:" + (.uuid | ascii_downcase)
  else "" end;
def protected:
  ((.parttype // "" | ascii_downcase) as $t |
    ["c12a7328-f81f-11d2-ba4b-00a0c93ec93b", "e3c9e316-0b5c-4db8-817d-f92df00215ae",
     "de94bba4-06d1-4d40-a16a-bfd50179d6ac", "0xef", "0x27"] | index($t)) != null
  or any(.mountpoints[]?; . == "/" or . == "/boot" or . == "/boot/efi" or . == "/efi"
    or (. != null and startswith("/run/archiso")));
def encrypted: (.fstype // "" | ascii_downcase) as $f |
  (["bitlocker", "crypto_bitlk", "crypto_luks"] | index($f)) != null;
[$devices[0].blockdevices[] | recurse(.children[]?)] as $all |
[$all[] | select(encrypted) | .children[]? | select(.type == "crypt") | .path] as $cleartexts |
[$all[] |
 select((.fstype // "") != "" and .type != "loop" and .type != "rom") |
 select(.path as $path | ($cleartexts | index($path)) == null) |
 . as $b | (id) as $id | (encrypted) as $encrypted |
 (first(.children[]? | select(.type == "crypt" and (.fstype // "") != "")) // null) as $clear |
 (if $encrypted and $clear != null then $clear else . end) as $volume |
 ((protected) or ($volume | protected)) as $protected |
 ($encrypted and $clear == null) as $locked |
 (first($mapping[0].drives[]? | select(.id == $id)) // {}) as $alias |
 ([$volume.mountpoints[]? | select(. != null and . != "")] | first // "") as $mount |
 (first($mounts[0].filesystems[]? | select(.target == $mount)) // {}) as $m |
 {id:$id, device:$volume.path, blockDevice:.path, uuid:(.uuid // ""), partuuid:(.partuuid // ""),
  label:(.label // ""), letter:($alias.letter // ""),
  name:(if ($alias.letter // "") != "" then
    (($alias.label // .label // "Drive") + " (" + $alias.letter + ":)")
    else (if (.label // "") == "" then "Local drive" else .label end) end),
  filesystem:$volume.fstype, encryption:(if $encrypted then .fstype else "" end),
  size:(.size | tonumber), mountpoint:$mount,
  mounted:($mount != ""), readOnly:(($volume.ro == true or $volume.ro == 1) or
    (($m.options // "" | split(",")) | index("ro")) != null),
  protected:$protected, locked:$locked, encrypted:$encrypted,
  canUnlock:($id != "" and ($protected | not) and $locked),
  canMount:($id != "" and ($protected | not) and ($locked | not) and
    (["ntfs","ntfs3","exfat","vfat","ext4","btrfs","xfs","f2fs"] | index($volume.fstype)) != null)}]
