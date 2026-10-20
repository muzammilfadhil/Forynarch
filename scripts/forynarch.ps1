param(
    [ValidateSet('Plan', 'Check', 'BuildRemote')]
    [string]$Action = 'Plan',
    [string]$SshTarget,
    [string]$RemotePath,
    [switch]$ApproveHostPackages,
    [switch]$ApproveTargetPackages,
    [switch]$ApproveImageConfig
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ($Action -eq 'Plan') {
    Write-Output 'Windows authors/checks source; Arch VM builds on a Linux-native filesystem.'
    Write-Output 'Local: .\scripts\forynarch.ps1 -Action Check'
    Write-Output 'Arch: sudo bash scripts/forynarch.sh build --approve-host-packages --approve-target-packages --approve-image-config'
    Write-Output 'Remote: provide your existing SSH target and absolute Linux repository path.'
    Write-Output 'No VM, package, account, disk, EFI or build changes are performed by Plan.'
    exit 0
}
if ($Action -eq 'Check') {
    Push-Location -LiteralPath $projectRoot
    try {
        & py -3 -m unittest discover -s tests -p 'test_*.py'
        if ($LASTEXITCODE -ne 0) { throw 'Python contract tests failed.' }
        $bashCandidates = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
            Where-Object { $_ } | ForEach-Object { Join-Path $_ 'Git/bin/bash.exe' }
        $gitBash = $bashCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if (-not $gitBash) { throw 'Git Bash is unavailable; no package installation will be attempted.' }
        foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.sh' -File) {
            & $gitBash -n ('scripts/' + $file.Name)
            if ($LASTEXITCODE -ne 0) { throw ('Bash syntax failed: ' + $file.Name) }
        }
        & $gitBash scripts/forynarch.sh plan
        if ($LASTEXITCODE -ne 0) { throw 'Pipeline plan failed.' }
        Write-Output 'Local source checks passed. Arch runtime and disk tests remain separate.'
    } finally { Pop-Location }
    exit 0
}
# Only an existing Arch VM is used. Do not run mkarchiso from PowerShell/WSL.
if ($SshTarget -notmatch '^[A-Za-z0-9][A-Za-z0-9_.@-]*$') { throw 'Provide a valid SSH host or user@host.' }
if ($RemotePath -notmatch '^/[A-Za-z0-9_./-]+$' -or ($RemotePath.Split('/') -contains '..')) {
    throw 'Provide an absolute Linux repository path without spaces or parent traversal.'
}
if (-not $ApproveTargetPackages -or -not $ApproveImageConfig) {
    throw 'Remote build requires explicit target package and image configuration approval switches.'
}
$remoteArguments = ' --approve-target-packages --approve-image-config'
if ($ApproveHostPackages) { $remoteArguments += ' --approve-host-packages' }
$remoteCommand = "cd '$RemotePath' && sudo bash scripts/forynarch.sh build$remoteArguments"
& ssh -t -- $SshTarget $remoteCommand
if ($LASTEXITCODE -ne 0) { throw 'Remote pipeline stopped; inspect its retained evidence.' }
