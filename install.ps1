param([ValidateSet('codex','claude-code','cursor','antigravity')][string]$Target = 'claude-code', [string]$ArchiveUrl = '')
$Prefix = 'PLUGLAYER'
if (!$ArchiveUrl) { $ArchiveUrl = 'https://github.com/pluglayer/claude-plugin/archive/refs/heads/main.zip' }
# Generated entry points prepend one product's constants and remove the other
# visibility scope before this file is shipped.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($env:OS -ne 'Windows_NT') { throw 'Use install.sh on macOS or Linux.' }
if (![Environment]::Is64BitProcess) { throw 'PlugLayer requires 64-bit PowerShell on Windows.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installUser = [Environment]::GetFolderPath('UserProfile')
$installKey = [Environment]::GetEnvironmentVariable($Prefix + '_API_KEY')
$installUrl = [Environment]::GetEnvironmentVariable($Prefix + '_API_URL')
[Environment]::SetEnvironmentVariable($Prefix + '_API_KEY', $null)
[Environment]::SetEnvironmentVariable($Prefix + '_API_URL', $null)
$installTemp = Join-Path ([IO.Path]::GetTempPath()) ('pluglayer-native-' + [guid]::NewGuid())
try {
    New-Item -ItemType Directory -Path $installTemp | Out-Null
    $source = $PSScriptRoot
    if (!$source -or !(Test-Path -LiteralPath (Join-Path $source 'install-windows.py'))) {
        $zip = Join-Path $installTemp 'plugin.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $ArchiveUrl -OutFile $zip
        $unpacked = Join-Path $installTemp 'source'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
        $folders = @(Get-ChildItem -LiteralPath $unpacked -Directory)
        if ($folders.Count -ne 1) { throw 'Unexpected plugin archive structure.' }
        $source = $folders[0].FullName
    }
    if (!(Test-Path -LiteralPath (Join-Path $source 'install-windows.py'))) { throw 'Incomplete Windows installer bundle.' }
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    $uvx = Get-Command uvx -ErrorAction SilentlyContinue
    if (!$uv -or !$uvx) {
        Write-Host 'Installing the Python runtime manager...'
        Invoke-RestMethod 'https://astral.sh/uv/install.ps1' | Invoke-Expression
        $localBin = Join-Path $installUser '.local\bin'
        $cargoBin = Join-Path $installUser '.cargo\bin'
        $env:PATH = $localBin + ';' + $cargoBin + ';' + $env:PATH
        $uv = Get-Command uv -ErrorAction Stop
        $uvx = Get-Command uvx -ErrorAction SilentlyContinue
    }
    if (!$uvx) { throw 'uvx is unavailable after installing uv. Restart PowerShell and run the installer again.' }
    & $uv.Source python install 3.12
    if ($LASTEXITCODE -ne 0) { throw 'Could not install Python 3.12.' }
    $python = & $uv.Source python find 3.12
    if ($LASTEXITCODE -ne 0) { throw 'Could not locate Python 3.12.' }
    $python = ($python | Select-Object -Last 1).Trim()
    [Environment]::SetEnvironmentVariable($Prefix + '_API_KEY', $installKey)
    [Environment]::SetEnvironmentVariable($Prefix + '_API_URL', $installUrl)
    & $python (Join-Path $source 'install-windows.py') --target $Target --source $source --uv $uv.Source
    if ($LASTEXITCODE -ne 0) { throw 'PlugLayer installation failed. Review the error above and generate a new command if needed.' }
} finally {
    [Environment]::SetEnvironmentVariable($Prefix + '_API_KEY', $installKey)
    [Environment]::SetEnvironmentVariable($Prefix + '_API_URL', $installUrl)
    if (Test-Path -LiteralPath $installTemp) { Remove-Item -LiteralPath $installTemp -Recurse -Force }
}
