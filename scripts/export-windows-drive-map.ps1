param([Parameter(Mandatory=$true)][string]$Destination)
$ErrorActionPreference = 'Stop'
$entries = @(
    Get-Partition | Where-Object { $_.DriveLetter -match '^[C-Z]$' -and $_.Guid } | ForEach-Object {
        $identity = ([string]$_.Guid).Trim('{}').ToLowerInvariant()
        if ($identity -notmatch '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$') { return }
        $letter = [string]$_.DriveLetter
        $label = if ($letter + ':' -eq $env:SystemDrive) { 'Windows' } else { 'Drive ' + $letter }
        @{ id = 'partuuid:' + $identity; letter = $letter; label = $label }
    }
)
if ($entries.Count -eq 0) { throw 'No GPT drive letters could be exported. Assign aliases in Forynarch instead.' }
$resolved = [IO.Path]::GetFullPath($Destination)
[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($resolved)) | Out-Null
$data = @{ version = 1; drives = $entries } | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText($resolved, $data + "`n", [Text.UTF8Encoding]::new($false))
Write-Output "Exported $($entries.Count) drive letters to $resolved. No disks were changed."
