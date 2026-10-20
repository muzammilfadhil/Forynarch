param([string]$OutputPath)
$ErrorActionPreference = 'Stop'
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'out/windows-drives.json'
}
# Read Windows metadata only. Never mount, unlock, relabel or repartition.
$driveRecords = @(Get-Partition | Where-Object { $_.DriveLetter -match '^[C-Z]$' } | ForEach-Object {
    $partitionInfo = $_
    $partitionGuid = ([string]$partitionInfo.Guid).Trim('{}').ToLowerInvariant()
    if ($partitionGuid -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { return }
    $volumeInfo = $partitionInfo | Get-Volume
    $volumeLabel = [string]$volumeInfo.FileSystemLabel
    if (-not $volumeLabel) { $volumeLabel = if ($partitionInfo.DriveLetter -eq 'C') { 'Windows' } else { 'Data' } }
    $volumeLabel = [regex]::Replace($volumeLabel, '[\x00-\x1f\x7f]', ' ')
    if ($volumeLabel.Length -gt 64) { $volumeLabel = $volumeLabel.Substring(0, 64) }
    [ordered]@{ id = 'partuuid:' + $partitionGuid; letter = [string]$partitionInfo.DriveLetter; label = $volumeLabel }
})
if ($driveRecords.Count -eq 0) { throw 'No lettered GPT partitions found. Use manual Linux aliases for MBR or unsupported volumes.' }
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $resolvedOutput) { throw 'Output already exists; choose a new path to preserve it.' }
$outputDirectory = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$document = [ordered]@{ version = 1; drives = $driveRecords }
[IO.File]::WriteAllText($resolvedOutput, ($document | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
Write-Output "Exported $($driveRecords.Count) drive labels. No disk changes were made."
