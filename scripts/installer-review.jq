# Validate public setup choices. The privileged transport repeats this review.
. as $storage | ($request.selectedDrivers//[]) as $ids |
($info.drivers.choices) as $drivers |
if ($request|has("password") or has("confirmation")) then error("Account secrets are not accepted by the review service.")
elif ($ids|type)!="array" or any($ids[];type!="string") then error("Invalid driver selections.")
elif any($ids[];. as $id | any($drivers[];.id==$id)|not) then error("Unknown driver selection.")
elif any($drivers[]; .id as $id | ($ids|index($id))!=null and (.blocked//false)) then error("This driver requires an implemented compatibility check.")
elif ($request.offline//false) and ($ids|length)>0 then error("Additional drivers are unavailable in offline mode.")
elif any($drivers[]; . as $driver | ($ids|index($driver.id))!=null and (any($info.graphics[];.vendor==$driver.vendor)|not)) then error("The selected driver does not match detected hardware.")
elif $request.locale!="en_US.UTF-8" then error("The installed interface uses English.")
elif ($info.timezones|index($request.timezone))==null then error("Choose an available timezone.")
elif (["us","gb","de","fr","es","br","jp","id"]|index($request.keyboard))==null then error("Choose an available keyboard layout.")
else $storage + {
  selectedDrivers:($ids|unique),
  driverPackages:([$drivers[]|select(.id as $id|$ids|index($id))|.packages[]]|unique),
  system:{locale:"en_US.UTF-8",timezone:$request.timezone,keyboard:$request.keyboard},
  canExecute:false,reviewOnly:true,
  blockers:(.blockers +
    (if ($info.secureBootEnabled//false) then ["This installer does not support Secure Boot. Check firmware boot settings before installing."] else [] end) +
    (if ($info.executorAvailable//false|not) then ["The installation payload is unavailable or does not match this installer. Boot the current Forynarch ISO."] else [] end) +
    (if $request.filesystem!="ext4" then ["Installation currently requires an ext4 root filesystem."] else [] end))
  } |
  if .kind=="install-erase" then
    .canExecute=(.blockers|length==0) | .reviewOnly=(.canExecute|not)
  else . end
  end
