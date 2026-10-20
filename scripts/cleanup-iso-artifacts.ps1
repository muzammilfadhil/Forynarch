param([switch]$Apply, [ValidateRange(2,20)][int]$KeepLatest = 2)
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$isoRoot = [IO.Path]::GetFullPath((Join-Path $repo 'out/iso'))
foreach ($directory in @((Join-Path $repo 'out'), $isoRoot)) {
    $entry = Get-Item -LiteralPath $directory
    if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing a linked artifact directory: $directory" }
}
$vbox = Join-Path $env:ProgramFiles 'Oracle/VirtualBox/VBoxManage.exe'
if (!(Test-Path -LiteralPath $vbox -PathType Leaf)) { throw 'VirtualBox is required to check ISO references.' }
$files = @(Get-ChildItem -LiteralPath $isoRoot -Filter 'forynarch-*.iso' -File | Sort-Object LastWriteTimeUtc -Descending)
$latest = @($files | Select-Object -First $KeepLatest | ForEach-Object { $_.FullName })
$plan = @()
foreach ($file in $files) {
    if ($file.DirectoryName -ne $isoRoot -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Unexpected artifact path.' }
    $info = @(& $vbox showmediuminfo dvd $file.FullName 2>&1)
    if ($LASTEXITCODE) { throw "Cannot verify references for $($file.Name). Nothing is deleted without this check." }
    $used = @($info | Where-Object { "$_" -match '^In use by VMs:|^State:\s+locked' }).Count -gt 0
    $plan += [pscustomobject]@{Path=$file.FullName;Bytes=$file.Length;Action=$(if($used){'Keep: VM reference'}elseif($latest -contains $file.FullName){'Keep: recent release'}else{'Delete'})}
}
$report = Join-Path $repo 'out/iso-cleanup-plan.json'
$plan | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $report -Encoding UTF8
foreach ($item in $plan) { '{0}: {1:N2} GiB  {2}' -f $item.Action,($item.Bytes/1GB),[IO.Path]::GetFileName($item.Path) }
$selected = @($plan | Where-Object Action -eq 'Delete')
$bytes = ($selected | Measure-Object Bytes -Sum).Sum
'Selected: {0} ISO files, {1:N2} GiB. Apply: {2}' -f $selected.Count,($bytes/1GB),[bool]$Apply
if (!$Apply) { return }
foreach ($item in $selected) {
    $resolved = (Resolve-Path -LiteralPath $item.Path).Path
    if ([IO.Path]::GetDirectoryName($resolved) -ne $isoRoot) { throw 'Artifact escaped its directory.' }
    & $vbox closemedium dvd $resolved
    if ($LASTEXITCODE) { throw "VirtualBox refused to release $resolved; it has not been deleted." }
    Remove-Item -LiteralPath $resolved -Force
    $checksum = $resolved + '.sha256'
    if (Test-Path -LiteralPath $checksum -PathType Leaf) {
        $sidecar = Get-Item -LiteralPath $checksum
        if (!($sidecar.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Remove-Item -LiteralPath $checksum -Force }
    }
}
'Removed {0} unused ISO files ({1:N2} GiB).' -f $selected.Count,($bytes/1GB)
