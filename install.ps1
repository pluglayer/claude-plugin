$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$target = $env:PLUGLAYER_INSTALL_TARGET
$label = $env:PLUGLAYER_INSTALL_LABEL
$version = $env:PLUGLAYER_PLUGIN_VERSION
$environmentId = $env:PLUGLAYER_INSTALL_ENVIRONMENT
$source = $env:PLUGLAYER_PLUGIN_SOURCE_DIR
$cliGuide = $env:PLUGLAYER_CLI_GUIDE
$cliInstaller = $env:PLUGLAYER_CLI_INSTALLER
$installedUrl = $env:PLUGLAYER_INSTALLED_URL
$failureUrl = $env:PLUGLAYER_INSTALL_FAILURE_URL
$work = Join-Path ([IO.Path]::GetTempPath()) ('pluglayer-oauth-' + [guid]::NewGuid())
function Say([string]$Message) { Write-Host "`n$Message" }
function Run([string]$File, [string[]]$Arguments) { & $File @Arguments; if ($LASTEXITCODE -ne 0) { throw "$File failed ($LASTEXITCODE). Follow $cliGuide and retry." } }
function Find-Agent {
    $names = switch ($target) { 'codex' { @('codex') } 'claude-code' { @('claude') } 'cursor' { @('agent','cursor-agent') } 'antigravity' { @('agy') } }
    foreach ($name in $names) { $found = Get-Command $name -ErrorAction SilentlyContinue; if ($found) { return $found.Source } }
    return $null
}
function Assert-Same([string]$First, [string]$Second) {
    if (!(Test-Path -LiteralPath $First -PathType Container) -or !(Test-Path -LiteralPath $Second -PathType Container)) { return $false }
    $a = @(Get-ChildItem -LiteralPath $First -Recurse -File); $b = @(Get-ChildItem -LiteralPath $Second -Recurse -File)
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($file in $a) { $relative = $file.FullName.Substring($First.Length).TrimStart('\','/'); $other = Join-Path $Second $relative; if (!(Test-Path -LiteralPath $other -PathType Leaf)) { return $false }; if ((Get-FileHash $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $other -Algorithm SHA256).Hash) { return $false } }
    return $true
}
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 16), (New-Object Text.UTF8Encoding($false))) }
try {
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $env:PATH = (Join-Path $env:LOCALAPPDATA 'agy\bin') + ';' + (Join-Path $HOME '.local\bin') + ';' + (Join-Path $HOME '.cursor\bin') + ';' + $env:PATH
    Say "1/4 · Checking $label requirements"
    $cli = Find-Agent
    if (!$cli) {
        $answer = Read-Host "Install the official $label CLI now? [y/N]"
        if ($answer -notmatch '^(y|yes)$' -or !$cliInstaller) { Start-Process $cliGuide; throw "Follow $cliGuide, open a new terminal, and rerun the command." }
        $entry = Join-Path $work 'agent-install.ps1'; Invoke-WebRequest -UseBasicParsing -Uri $cliInstaller -OutFile $entry
        Run 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File',$entry); $env:PATH = [Environment]::GetEnvironmentVariable('PATH','User') + ';' + $env:PATH; $cli = Find-Agent
    }
    if (!$cli) { throw 'The CLI is not on PATH yet. Open a new terminal and retry.' }
    Run $cli @('--help'); if ($target -ne 'cursor') { Run $cli @('plugin','--help') }
    if (!(Test-Path -LiteralPath $source -PathType Container)) { throw 'The installer bundle is incomplete. Generate a new command.' }
    Say "2/4 · Preparing complete PlugLayer $version package"
    $package = Join-Path (Join-Path (Join-Path $HOME '.pluglayer\plugin-packages') $target) ($version + '-' + $environmentId)
    New-Item -ItemType Directory -Force -Path (Split-Path $package) | Out-Null
    if (Test-Path -LiteralPath $package) { if (!(Assert-Same $source $package)) { throw "Preserving edited package: $package. Resolve it using the prompt option." } } else { Copy-Item -LiteralPath $source -Destination $package -Recurse }
    Say "3/4 · Registering skills, agents and hosted MCP in $label"
    $marketName = 'pluglayer-direct-' + $environmentId
    if ($target -eq 'codex' -or $target -eq 'claude-code') {
        $marketplace = Join-Path (Join-Path $HOME '.pluglayer\marketplaces') ($target + '-' + $environmentId)
        $catalogDir = if ($target -eq 'codex') { '.agents\plugins' } else { '.claude-plugin' }
        New-Item -ItemType Directory -Force -Path (Join-Path $marketplace $catalogDir) | Out-Null
        if ($target -eq 'codex') { $catalog = @{ name=$marketName; plugins=@(@{name='pluglayer-codex-plugin';source=@{source='local';path=$package};policy=@{installation='AVAILABLE';authentication='ON_INSTALL'};category='Developer Tools'}) }; Write-Json (Join-Path (Join-Path $marketplace $catalogDir) 'marketplace.json') $catalog; Run $cli @('plugin','marketplace','add',$marketplace); Run $cli @('plugin','add',('pluglayer-codex-plugin@' + $marketName)) }
        else { $catalog = @{ name=$marketName; owner=@{name='PlugLayer'}; plugins=@(@{name='pluglayer';source=$package;version=$version}) }; Write-Json (Join-Path (Join-Path $marketplace $catalogDir) 'marketplace.json') $catalog; Run $cli @('plugin','marketplace','add',$marketplace); Run $cli @('plugin','install',('pluglayer@' + $marketName),'--scope','user') }
        Run $cli @('plugin','list')
    } elseif ($target -eq 'cursor') {
        $dest = Join-Path $HOME '.cursor\plugins\local\pluglayer-cursor-plugin'; $managed = Join-Path $HOME ('.pluglayer\plugin-state\cursor-' + $environmentId)
        if ((Test-Path -LiteralPath $dest) -and !(Assert-Same $dest $package)) { if (!(Assert-Same $dest $managed)) { throw "Preserving user-edited Cursor plugin: $dest. Resolve it using the prompt option." }; Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest),(Split-Path $managed) | Out-Null; if (!(Test-Path $dest)) { Copy-Item $package $dest -Recurse }; if (Test-Path $managed) { Remove-Item $managed -Recurse -Force }; Copy-Item $package $managed -Recurse; Say 'Cursor loads the complete local plugin. Reload any open Cursor window.'
    } else { Run $cli @('plugin','install',$package); Run $cli @('plugin','list') }
    try { Invoke-RestMethod -Method Post -Uri $installedUrl | Out-Null } catch { Write-Warning 'Package installed; portal status could not refresh.' }
    Say "4/4 · PlugLayer $version installed in $label"
    Say "Restart or reload $label if the plugin is not visible in your current session."
    Say "Connect PlugLayer through $label's native plugin connection UI when needed."
} catch { try { Invoke-RestMethod -Method Post -Uri $failureUrl | Out-Null } catch {}; throw } finally { if (Test-Path $work) { Remove-Item $work -Recurse -Force } }
