param(
    [switch]$ApproveBuilderProvisioning,
    [switch]$RunBuild,
    [switch]$ResumeInstalledBuilder,
    [switch]$AllowReviewedPythonRuntime,
    [ValidateSet('classic','glass')][string]$DesktopShell = 'classic',
    [switch]$ApproveBuilderPackageUpdate
)
$ErrorActionPreference = 'Stop'
if (-not $ApproveBuilderProvisioning) {
    throw 'Explicit approval is required: new blank VM disk, Arch/build packages, SSH-key builder administrator and passwordless sudo.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = Join-Path $projectRoot 'out/virtualbox'
$statePath = Join-Path $runtimeRoot 'builder-state.json'
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($state.vm_name -ne 'Forynarch-Builder' -or $state.disk_bytes -ne 85899345920 -or
    $state.pgp_verification -ne 'passed-wkd-pierre@archlinux.org') { throw 'Prepared/verified VM state required.' }
$vbox = Join-Path $env:ProgramFiles 'Oracle/VirtualBox/VBoxManage.exe'
function VBox([string[]]$Arguments) {
    $output = & $vbox @Arguments
    if ($LASTEXITCODE -ne 0) { throw ('VirtualBox failed: ' + $Arguments[0]) }
    return $output
}
function Save-State {
    [IO.File]::WriteAllText($statePath, (($state | ConvertTo-Json) -replace "`r`n", "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
}
function Vm-State {
    $info = VBox @('showvminfo', $state.vm_uuid, '--machinereadable')
    $line = $info | Where-Object { $_ -match '^VMState="([^"]+)"$' } | Select-Object -First 1
    if (-not $line) { throw 'VM state unavailable.' }
    return [regex]::Match($line, '^VMState="([^"]+)"$').Groups[1].Value
}
function Free-Port {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}
function Await-Poweroff {
    for ($attempt = 0; $attempt -lt 90; $attempt++) {
        if ((Vm-State) -eq 'poweroff') { return }
        Start-Sleep -Seconds 2
    }
    throw 'Graceful VM shutdown did not finish; no forced poweroff attempted.'
}
$info = VBox @('showvminfo', $state.vm_uuid, '--machinereadable')
$diskLine = $info | Where-Object { $_ -match '^"SATA-0-0"=' } | Select-Object -First 1
if (-not $diskLine) { throw 'Approved disk attachment is unavailable.' }
$reportedDisk = $diskLine.Substring($diskLine.IndexOf('=') + 1).Trim('"').Replace('\\', '\').Replace('/', '\')
if (-not [string]::Equals([IO.Path]::GetFullPath($reportedDisk), [IO.Path]::GetFullPath($state.disk_path), [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Approved disk attachment changed.'
}
if ((Get-Item -LiteralPath $state.disk_path).Extension -ne '.vdi') { throw 'A generated VDI is required.' }
$state.provisioning_approval = 'user-approved-builder-disk-packages-admin-efi-build-tests'
Save-State

if ($ResumeInstalledBuilder -and -not $state.os_installed) {
    $previousJob = Get-ChildItem -LiteralPath $runtimeRoot -Directory -Filter 'provision-*' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $previousJob -or -not (Test-Path -LiteralPath (Join-Path $previousJob.FullName 'guest-status.txt')) -or
        [IO.File]::ReadAllText((Join-Path $previousJob.FullName 'guest-status.txt')).Trim() -ne 'completed') {
        throw 'Resume requires a completed provisioning checkpoint; no disk setup will be repeated.'
    }
    $forwarding = $info | Where-Object { $_ -match '"builder-ssh,tcp,127\.0\.0\.1,([0-9]+),,22"$' } | Select-Object -First 1
    if (-not $forwarding) { throw 'Existing builder SSH forwarding rule unavailable.' }
    $resumedPort = [int][regex]::Match($forwarding, '127\.0\.0\.1,([0-9]+),,22').Groups[1].Value
    if ((Vm-State) -eq 'running') { VBox @('controlvm', $state.vm_uuid, 'acpipowerbutton') | Out-Null; Await-Poweroff }
    if ((Vm-State) -ne 'poweroff') { throw 'Completed builder must be powered off before media handoff.' }
    VBox @('storageattach', $state.vm_uuid, '--storagectl', 'SATA', '--port', '1', '--device', '0', '--type', 'dvddrive', '--medium', 'emptydrive') | Out-Null
    VBox @('modifyvm', $state.vm_uuid, '--boot1', 'disk', '--boot2', 'dvd', '--nat-localhostreachable1', 'off') | Out-Null
    $state.os_installed = $true
    $state | Add-Member -NotePropertyName ssh_port -NotePropertyValue $resumedPort -Force
    Save-State
    VBox @('startvm', $state.vm_uuid, '--type', 'headless') | Out-Null
    Write-Output 'Resumed the completed Arch installation at disk boot; no disk setup repeated.'
}

$sshDirectory = Join-Path $runtimeRoot 'ssh'
New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
$privateKey = Join-Path $sshDirectory 'builder_ed25519'
if (-not (Test-Path -LiteralPath $privateKey)) {
    & py -3 -c "import subprocess,sys; subprocess.run(['ssh-keygen.exe','-q','-t','ed25519','-N','','-C','forynarch-builder','-f',sys.argv[1]],check=True)" $privateKey
    if ($LASTEXITCODE -ne 0) { throw 'SSH key generation failed.' }
}
$ownerSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $privateKey /inheritance:r /grant:r ('*' + $ownerSid + ':(F)') | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Private SSH key ACL setup failed.' }
$knownHosts = Join-Path $sshDirectory 'known_hosts'
$publicDirectory = Join-Path $runtimeRoot ('provision-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $publicDirectory | Out-Null
Copy-Item -LiteralPath ($privateKey + '.pub') -Destination (Join-Path $publicDirectory 'builder.pub')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'bootstrap-virtualbox-arch.sh') -Destination (Join-Path $publicDirectory 'bootstrap.sh')
$httpPort = Free-Port
$sshPort = if ($state.PSObject.Properties.Name -contains 'ssh_port') { $state.ssh_port } else { Free-Port }
$guestScript = @'
#!/usr/bin/env bash
set -Eeuo pipefail
endpoint=http://10.0.2.2:{{PORT}}
send_log() { [[ ! -f /tmp/forynarch-bootstrap.log ]] || curl -fsS -X POST --data-binary @/tmp/forynarch-bootstrap.log "$endpoint/log" >/dev/null; }
failed() { send_log || true; curl -fsS -X POST --data failed "$endpoint/status" >/dev/null || true; }
trap failed ERR
curl -fsS -X POST --data started "$endpoint/status" >/dev/null
curl -fsS "$endpoint/builder.pub" -o /tmp/forynarch-builder.pub
curl -fsS "$endpoint/bootstrap.sh" -o /tmp/forynarch-bootstrap.sh
bash /tmp/forynarch-bootstrap.sh --approve-blank-vm-disk --approve-builder-packages --approve-builder-admin --public-key /tmp/forynarch-builder.pub 2>&1 |
  sed -u -E 's/[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}/[uuid-redacted]/g' | tee /tmp/forynarch-bootstrap.log
send_log
curl -fsS -X POST --data completed "$endpoint/status" >/dev/null
'@
$guestScript = $guestScript.Replace('{{PORT}}', [string]$httpPort) -replace "`r`n", "`n"
[IO.File]::WriteAllText((Join-Path $publicDirectory 'run.sh'), $guestScript + "`n", (New-Object Text.UTF8Encoding($false)))
$pythonExecutable = (& py -3 -c 'import sys; print(sys.executable)').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Python executable lookup failed.' }
$serverArguments = @(('"' + (Join-Path $PSScriptRoot 'virtualbox_transport.py') + '"'), '--directory', ('"' + $publicDirectory + '"'), '--port', [string]$httpPort)
$server = Start-Process -FilePath $pythonExecutable -ArgumentList $serverArguments -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $publicDirectory 'transport.stdout.log') -RedirectStandardError (Join-Path $publicDirectory 'transport.stderr.log')
try {
    if (-not $state.os_installed) {
        Write-Output 'Preparing loopback-only provisioning transport and rebooting the approved Live VM.'
        if ((Vm-State) -eq 'running') { VBox @('controlvm', $state.vm_uuid, 'acpipowerbutton') | Out-Null; Await-Poweroff }
        VBox @('modifyvm', $state.vm_uuid, '--nat-localhostreachable1', 'on', '--nat-pf1', ('builder-ssh,tcp,127.0.0.1,' + $sshPort + ',,22')) | Out-Null
        VBox @('startvm', $state.vm_uuid, '--type', 'headless') | Out-Null
        Write-Output 'Waiting for Live boot before sending the approved provisioning script.'
        $liveReady = $false
        for ($bootAttempt = 0; $bootAttempt -lt 90; $bootAttempt++) {
            $users = VBox @('guestproperty', 'get', $state.vm_uuid, '/VirtualBox/GuestInfo/OS/LoggedInUsersList')
            $address = VBox @('guestproperty', 'get', $state.vm_uuid, '/VirtualBox/GuestInfo/Net/0/V4/IP')
            if (($users -join '') -eq 'Value: root' -and ($address -join '') -match '^Value: 10\.0\.2\.') {
                $liveReady = $true
                break
            }
            Start-Sleep -Seconds 3
        }
        if (-not $liveReady) { throw 'Live root login/network readiness was not confirmed; no provisioning command sent.' }
        VBox @('controlvm', $state.vm_uuid, 'keyboardputstring', ('curl -fsSL http://10.0.2.2:' + $httpPort + '/run.sh -o /tmp/forynarch-run.sh')) | Out-Null
        VBox @('controlvm', $state.vm_uuid, 'keyboardputscancode', '1c', '9c') | Out-Null
        Start-Sleep -Seconds 3
        VBox @('controlvm', $state.vm_uuid, 'keyboardputstring', 'bash /tmp/forynarch-run.sh') | Out-Null
        VBox @('controlvm', $state.vm_uuid, 'keyboardputscancode', '1c', '9c') | Out-Null
        $statusPath = Join-Path $publicDirectory 'guest-status.txt'
        for ($attempt = 0; $attempt -lt 240; $attempt++) {
            if (Test-Path -LiteralPath $statusPath) {
                $guestStatus = [IO.File]::ReadAllText($statusPath).Trim()
                if ($guestStatus -eq 'failed') { throw ('Guest provisioning failed; inspect ' + (Join-Path $publicDirectory 'guest-install.log')) }
                if ($guestStatus -eq 'completed') { break }
            }
            if ($attempt % 12 -eq 0) { Write-Output 'Arch builder provisioning is running; the approved disk is the new VM VDI.' }
            Start-Sleep -Seconds 5
        }
        if (-not (Test-Path $statusPath) -or [IO.File]::ReadAllText($statusPath).Trim() -ne 'completed') { throw 'Provisioning did not complete within the observation window.' }
        VBox @('controlvm', $state.vm_uuid, 'acpipowerbutton') | Out-Null
        Await-Poweroff
        VBox @('storageattach', $state.vm_uuid, '--storagectl', 'SATA', '--port', '1', '--device', '0', '--type', 'dvddrive', '--medium', 'emptydrive') | Out-Null
        VBox @('modifyvm', $state.vm_uuid, '--boot1', 'disk', '--boot2', 'dvd', '--nat-localhostreachable1', 'off') | Out-Null
        $state.os_installed = $true
        $state | Add-Member -NotePropertyName ssh_port -NotePropertyValue $sshPort -Force
        Save-State
        VBox @('startvm', $state.vm_uuid, '--type', 'headless') | Out-Null
    }
    $sshArguments = @('-i', $privateKey, '-p', [string]$sshPort, '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', '-o', 'KexAlgorithms=curve25519-sha256', '-o', 'StrictHostKeyChecking=yes', '-o', ('UserKnownHostsFile=' + $knownHosts))
    Write-Output 'Waiting for the installed Arch builder SSH service.'
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $client = New-Object Net.Sockets.TcpClient
        try { $task = $client.ConnectAsync('127.0.0.1', $sshPort); $ready = $task.Wait(1500) -and $client.Connected } catch { $ready = $false } finally { $client.Dispose() }
        if ($ready) { break }
        Start-Sleep -Seconds 3
    }
    if (-not $ready) { throw 'Installed builder SSH service is unavailable.' }
    if (-not (Test-Path -LiteralPath $knownHosts)) {
        $keyscanExecutable = Join-Path $env:ProgramFiles 'Git/usr/bin/ssh-keyscan.exe'
        if (-not (Test-Path -LiteralPath $keyscanExecutable)) { $keyscanExecutable = (Get-Command ssh-keyscan.exe).Source }
        & py -3 -c "import pathlib,subprocess,sys; r=subprocess.run([sys.argv[3],'-T','5','-p',sys.argv[1],'-t','ed25519','127.0.0.1'],capture_output=True); sys.exit(r.returncode or 1) if not r.stdout else pathlib.Path(sys.argv[2]).write_bytes(r.stdout)" ([string]$sshPort) $knownHosts $keyscanExecutable
        if ($LASTEXITCODE -ne 0) { throw 'Cannot pin the new isolated VM host key.' }
    }
    & ssh.exe @sshArguments builder@127.0.0.1 'uname -r'
    if ($LASTEXITCODE -ne 0) { throw 'Builder SSH authentication failed.' }
    & ssh.exe @sshArguments builder@127.0.0.1 'sudo -n true'
    if ($LASTEXITCODE -ne 0) { throw 'Approved builder sudo setup failed.' }
    $archivePath = Join-Path $publicDirectory 'forynarch-source.zip'
    & py -3 (Join-Path $PSScriptRoot 'source_archive.py') $projectRoot $archivePath
    if ($LASTEXITCODE -ne 0) { throw 'Source-only archive creation failed.' }
    $scpArguments = @('-i', $privateKey, '-P', [string]$sshPort, '-o', 'BatchMode=yes', '-o', 'KexAlgorithms=curve25519-sha256', '-o', 'StrictHostKeyChecking=yes', '-o', ('UserKnownHostsFile=' + $knownHosts))
    & scp.exe @scpArguments $archivePath 'builder@127.0.0.1:/tmp/forynarch-source.zip'
    if ($LASTEXITCODE -ne 0) { throw 'Source transfer failed.' }
    & ssh.exe @sshArguments builder@127.0.0.1 'mkdir -p /home/builder/Forynarch && unzip -oq /tmp/forynarch-source.zip -d /home/builder/Forynarch && mkdir -p /home/builder/Forynarch/work /home/builder/Forynarch/out'
    if ($LASTEXITCODE -ne 0) { throw 'Native-filesystem source extraction failed.' }
    Write-Output 'Arch builder installed, SSH/sudo verified and source transferred to ext4.'
    if ($RunBuild) {
        $buildCommand = 'cd /home/builder/Forynarch && sudo bash scripts/forynarch.sh build --approve-target-packages --approve-image-config'
        if ($AllowReviewedPythonRuntime) { $buildCommand += ' --allow-core-dependency python' }
        $buildCommand += ' --desktop-shell ' + $DesktopShell
        if ($ApproveBuilderPackageUpdate) { $buildCommand += ' --approve-host-packages' }
        & ssh.exe @sshArguments builder@127.0.0.1 $buildCommand
        if ($LASTEXITCODE -ne 0) { throw 'Pipeline stopped; inspect and repair the retained build evidence.' }
    }
} finally {
    if (-not $server.HasExited) { Stop-Process -Id $server.Id }
}
