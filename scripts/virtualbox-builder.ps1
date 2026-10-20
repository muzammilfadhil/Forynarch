param(
    [ValidateSet('Plan', 'Prepare', 'VerifySignature', 'Start', 'Status')]
    [string]$Action = 'Plan',
    [string]$VmName = 'Forynarch-Builder'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$generatedRoot = Join-Path $projectRoot 'out/virtualbox'
$runtimePath = Join-Path $generatedRoot 'builder-state.json'
$virtualBox = Join-Path $env:ProgramFiles 'Oracle/VirtualBox/VBoxManage.exe'
if (-not (Test-Path -LiteralPath $virtualBox)) {
    $command = Get-Command VBoxManage.exe -ErrorAction SilentlyContinue
    if (-not $command) { throw 'VirtualBox is not installed; this script will not install it.' }
    $virtualBox = $command.Source
}
if ($VmName -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$') { throw 'Invalid VM name.' }
function Invoke-VBox {
    param([string[]]$Arguments)
    & $virtualBox @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('VirtualBox operation failed: ' + $Arguments[0]) }
}
function Read-State {
    if (-not (Test-Path -LiteralPath $runtimePath)) { throw 'Run Prepare first.' }
    $state = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
    if ($state.vm_name -ne $VmName) { throw 'Runtime state belongs to another VM.' }
    return $state
}
if ($Action -eq 'Plan') {
    Write-Output "New VM: $VmName; 8192 MiB RAM; 4 CPUs; UEFI; 80 GiB dynamic VDI; NAT."
    Write-Output 'Only files under out/virtualbox are created. No physical/raw disk, shared folders or bridged network.'
    Write-Output 'Prepare downloads latest official Arch ISO, checks its published SHA-256 and creates the VM.'
    Write-Output 'Start boots the official ISO headlessly. No OS/package/account/EFI installation is performed.'
    Write-Output 'Builder provisioning requires a separate explicit approval for the new virtual disk and administrator.'
    exit 0
}
if ($Action -eq 'Status') {
    $state = Read-State
    Invoke-VBox -Arguments @('showvminfo', $state.vm_uuid, '--machinereadable')
    exit 0
}
if ($Action -eq 'VerifySignature') {
    $state = Read-State
    $gpg = Join-Path $env:ProgramFiles 'Git/usr/bin/gpg.exe'
    if (-not (Test-Path -LiteralPath $gpg)) {
        $gpgCommand = Get-Command gpg.exe -ErrorAction SilentlyContinue
        if (-not $gpgCommand) { throw 'GPG is unavailable; no package installation is attempted.' }
        $gpg = $gpgCommand.Source
    }
    $keyDirectory = Join-Path $generatedRoot 'public-keyring'
    New-Item -ItemType Directory -Path $keyDirectory -Force | Out-Null
    $signaturePath = $state.iso_path + '.sig'
    Invoke-WebRequest -UseBasicParsing -TimeoutSec 60 `
        -Uri ('https://geo.mirror.pkgbuild.com/iso/' + $state.iso_release + '/archlinux-' + $state.iso_release + '-x86_64.iso.sig') `
        -OutFile $signaturePath
    $gpgKeyDirectory = $keyDirectory
    $gpgSignaturePath = $signaturePath
    $gpgIsoPath = $state.iso_path
    if ($gpg -match '[\\/]Git[\\/]usr[\\/]bin[\\/]gpg.exe$') {
        $gpgPaths = @($keyDirectory, $signaturePath, $state.iso_path) | ForEach-Object {
            if ($_ -notmatch '^([A-Za-z]):[\\/](.*)$') { throw 'Unsupported Git GPG path.' }
            '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2].Replace('\', '/')
        }
        $gpgKeyDirectory, $gpgSignaturePath, $gpgIsoPath = $gpgPaths
    }
    & $gpg --homedir $gpgKeyDirectory --batch --auto-key-locate clear,wkd --locate-external-key pierre@archlinux.org
    if ($LASTEXITCODE -ne 0) { throw 'Official signing-key lookup failed; signature remains unverified.' }
    & $gpg --homedir $gpgKeyDirectory --batch --verify $gpgSignaturePath $gpgIsoPath
    if ($LASTEXITCODE -ne 0) { throw 'ISO signature verification failed.' }
    $state.pgp_verification = 'passed-wkd-pierre@archlinux.org'
    [IO.File]::WriteAllText($runtimePath, (($state | ConvertTo-Json) -replace "`r`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
    Write-Output 'Official Arch ISO signature verification passed using an isolated public keyring.'
    exit 0
}
if ($Action -eq 'Start') {
    $state = Read-State
    Invoke-VBox -Arguments @('startvm', $state.vm_uuid, '--type', 'headless')
    exit 0
}
# Refuse to repurpose, overwrite or delete an existing VM/disk.
$registered = & $virtualBox list vms
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate existing VMs.' }
if ($registered -match ('^"' + [regex]::Escape($VmName) + '" ')) {
    throw 'VM name already exists. Use Status; no existing VM is changed.'
}
$vmFolder = Join-Path $generatedRoot $VmName
if (Test-Path -LiteralPath $vmFolder) { throw 'VM folder already exists; review it instead of overwriting.' }
$resolvedGenerated = [IO.Path]::GetFullPath($generatedRoot)
$resolvedProject = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
if (-not $resolvedGenerated.StartsWith($resolvedProject, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Generated destination escaped workspace.'
}
foreach ($directory in @($projectRoot, (Join-Path $projectRoot 'out'), $generatedRoot, (Join-Path $generatedRoot 'media'))) {
    if (Test-Path -LiteralPath $directory) {
        if ((Get-Item -LiteralPath $directory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Generated path contains a junction/symlink; review required.'
        }
    }
}
New-Item -ItemType Directory -Path (Join-Path $generatedRoot 'media') -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$downloadPage = (Invoke-WebRequest -UseBasicParsing -Uri 'https://archlinux.org/download/').Content
$plainPage = [Net.WebUtility]::HtmlDecode(($downloadPage -replace '<[^>]+>', ' '))
$releaseMatch = [regex]::Match($plainPage, 'Current Release:\s*(\d{4}\.\d{2}\.\d{2})')
$hashMatch = [regex]::Match($plainPage, 'SHA256:\s*([a-fA-F0-9]{64})')
if (-not $releaseMatch.Success -or -not $hashMatch.Success) { throw 'Official release metadata format changed; review required.' }
$release = $releaseMatch.Groups[1].Value
$expectedHash = $hashMatch.Groups[1].Value.ToLowerInvariant()
$isoName = "archlinux-$release-x86_64.iso"
$isoPath = Join-Path (Join-Path $generatedRoot 'media') $isoName
if (-not (Test-Path -LiteralPath $isoPath)) {
    $partialPath = $isoPath + '.download'
    if ((Test-Path -LiteralPath $partialPath) -and ((Get-Item -LiteralPath $partialPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Download destination is a symlink.'
    }
    Write-Output "Downloading official Arch $release installation media..."
    & curl.exe --fail --location --retry 3 --connect-timeout 20 --max-time 900 --silent --show-error `
        --output $partialPath "https://geo.mirror.pkgbuild.com/iso/$release/$isoName"
    if ($LASTEXITCODE -ne 0) { throw 'ISO download failed; no VM was created.' }
    $downloadHash = (Get-FileHash -LiteralPath $partialPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($downloadHash -ne $expectedHash) { throw 'ISO checksum mismatch; no VM was created.' }
    Move-Item -LiteralPath $partialPath -Destination $isoPath
}
if ((Get-FileHash -LiteralPath $isoPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
    throw 'Existing ISO does not match official SHA-256.'
}
Write-Output "Verified official Arch $release SHA-256. Preparing a new blank virtual disk."
Invoke-VBox -Arguments @('createvm', '--name', $VmName, '--platform-architecture', 'x86', '--ostype', 'ArchLinux_64', '--basefolder', $generatedRoot, '--register')
Invoke-VBox -Arguments @('modifyvm', $VmName, '--memory', '8192', '--cpus', '4', '--firmware', 'efi', '--ioapic', 'on', '--graphicscontroller', 'vmsvga', '--vram', '128', '--nic1', 'nat', '--boot1', 'dvd', '--boot2', 'disk', '--clipboard-mode', 'disabled', '--drag-and-drop', 'disabled')
$diskPath = Join-Path $vmFolder 'builder.vdi'
Invoke-VBox -Arguments @('createmedium', 'disk', '--filename', $diskPath, '--size', '81920', '--format', 'VDI', '--variant', 'Standard')
Invoke-VBox -Arguments @('storagectl', $VmName, '--name', 'SATA', '--add', 'sata', '--controller', 'IntelAhci', '--portcount', '2')
Invoke-VBox -Arguments @('storageattach', $VmName, '--storagectl', 'SATA', '--port', '0', '--device', '0', '--type', 'hdd', '--medium', $diskPath)
Invoke-VBox -Arguments @('storageattach', $VmName, '--storagectl', 'SATA', '--port', '1', '--device', '0', '--type', 'dvddrive', '--medium', $isoPath)
$vmInfo = & $virtualBox showvminfo $VmName --machinereadable
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify created VM.' }
$uuidLine = $vmInfo | Where-Object { $_ -match '^UUID="([^"]+)"$' } | Select-Object -First 1
if (-not $uuidLine) { throw 'Cannot obtain VM UUID.' }
$uuid = [regex]::Match($uuidLine, '^UUID="([^"]+)"$').Groups[1].Value
$state = [ordered]@{
    vm_name = $VmName; vm_uuid = $uuid; iso_release = $release; iso_sha256 = $expectedHash;
    iso_path = $isoPath; disk_path = $diskPath; disk_bytes = 85899345920;
    memory_mib = 8192; cpus = 4; os_installed = $false;
    provisioning_approval = 'required'; checksum_verification = 'official-https-sha256';
    pgp_verification = 'pending'
}
$stateJson = ($state | ConvertTo-Json) -replace "`r`n", "`n"
[IO.File]::WriteAllText($runtimePath, $stateJson + "`n", (New-Object Text.UTF8Encoding($false)))
Write-Output 'VM ready. The virtual disk is blank; Arch installation/account/package/EFI approval is still required.'
