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
    $a = @(Get-ChildItem -LiteralPath $First -Recurse -File -Force); $b = @(Get-ChildItem -LiteralPath $Second -Recurse -File -Force)
    if ($a.Count -ne $b.Count) { return $false }
    foreach ($file in $a) { $relative = $file.FullName.Substring($First.Length).TrimStart('\','/'); $other = Join-Path $Second $relative; if (!(Test-Path -LiteralPath $other -PathType Leaf)) { return $false }; if ((Get-FileHash $file.FullName -Algorithm SHA256).Hash -ne (Get-FileHash $other -Algorithm SHA256).Hash) { return $false } }
    return $true
}
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 64), (New-Object Text.UTF8Encoding($false))) }
function Capture-Native([string[]]$Arguments) {
    $previous = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $cli @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previous }
    return @{ output=($output -join "`n"); exitCode=$exitCode }
}
function Remove-LegacyPlugin([string]$Selector) {
    $result = Capture-Native @('plugin','remove',$Selector)
    if ($result.exitCode -ne 0 -and $result.output -notmatch '(?i)not installed|not found|could not find|no plugin') {
        throw "Could not migrate the existing PlugLayer registration: $Selector. Resolve the native plugin manager error and retry."
    }
}
function Remove-LegacyMarketplace([string]$Name) {
    $result = Capture-Native @('plugin','marketplace','remove',$Name)
    if ($result.exitCode -ne 0 -and $result.output -notmatch '(?i)not configured|not found|not added|could not find') {
        throw "Could not migrate the old PlugLayer marketplace: $Name"
    }
}
function Read-Catalog([string]$Path) {
    if ((Get-Item -LiteralPath $Path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Preserving linked catalog: $Path" }
    $catalog = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if (!$catalog.name -or $catalog.plugins -isnot [array]) { throw "Preserving unreadable plugin catalog: $Path" }
    return $catalog
}
function Migrate-Catalog([string]$Path, [string]$Selector) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $catalog = Read-Catalog $Path
    if (!@($catalog.plugins | Where-Object { $_.name -eq $publicName }).Count) { return }
    $catalog.plugins = @($catalog.plugins | Where-Object { $_.name -ne $publicName })
    # Serialize before removing registration; preserve unrelated data and backup.
    $content = $catalog | ConvertTo-Json -Depth 64
    Remove-LegacyPlugin $Selector
    $backup = $Path + '.pluglayer-backup'
    if (!(Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $Path -Destination $backup }
    $replacement = Join-Path (Split-Path $Path) ('.pluglayer-catalog-' + [guid]::NewGuid())
    try {
        [IO.File]::WriteAllText($replacement, $content, (New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $replacement -Destination $Path -Force
    } finally { if (Test-Path -LiteralPath $replacement) { Remove-Item -LiteralPath $replacement } }
}
function Migrate-PublicCatalogs {
    if ($target -eq 'codex') { Migrate-Catalog (Join-Path $HOME '.agents\plugins\marketplace.json') ($publicName + '@personal') }
    $root = Join-Path $HOME '.pluglayer\marketplaces'
    foreach ($legacy in @(Get-ChildItem -LiteralPath $root -Directory)) {
        if ($legacy.Name -notlike ($target + '-*') -and !($target -eq 'claude-code' -and $legacy.Name -like 'claude-*')) { continue }
        $path = Join-Path (Join-Path $legacy.FullName $catalogDir) 'marketplace.json'
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $catalog = Read-Catalog $path
        if ($catalog.name -notmatch '^pluglayer-direct-([a-f0-9]{12}|local)$') { continue }
        $matching = @($catalog.plugins | Where-Object { $_.name -eq $publicName }).Count
        if (!$matching) { continue }
        Migrate-Catalog $path ($publicName + '@' + $catalog.name)
        if ($catalog.plugins.Count -eq $matching) { Remove-LegacyMarketplace $catalog.name }
    }
}
function Register-PublicMarketplace {
    $result = Capture-Native @('plugin','marketplace','add',$marketplace)
    if ($result.exitCode -eq 0) { Write-Host $result.output; return }
    if ($target -eq 'codex') {
        $rows = & $cli plugin marketplace list
        if ($LASTEXITCODE -ne 0) { throw 'Could not inspect plugin marketplaces.' }
        $oldRoot = @($rows | Where-Object { $_ -match '^pluglayer\s+' } | ForEach-Object { $_ -replace '^pluglayer\s+', '' }) -join ''
    } else {
        $known = Get-Content -LiteralPath (Join-Path $HOME '.claude\plugins\known_marketplaces.json') -Raw | ConvertFrom-Json
        $oldRoot = $known.pluglayer.installLocation
    }
    if (!$oldRoot) { throw 'Could not register PlugLayer. Resolve the native marketplace error and retry.' }
    $catalog = Read-Catalog (Join-Path (Join-Path $oldRoot $catalogDir) 'marketplace.json')
    if ($catalog.name -ne 'pluglayer' -or !$catalog.plugins.Count -or @($catalog.plugins | Where-Object { $_.name -ne $publicName }).Count) {
        throw 'Preserving a customized PlugLayer marketplace containing other plugins.'
    }
    Run $cli @('plugin','marketplace','remove','pluglayer')
    Run $cli @('plugin','marketplace','add',$marketplace)
}
function Write-PublicCatalog([string]$Path, $Value) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existing = Read-Catalog $Path
        if ($existing.name -ne 'pluglayer' -or $existing.plugins.Count -ne 1 -or $existing.plugins[0].name -ne $publicName) {
            throw 'Preserving a customized PlugLayer catalog containing other plugins.'
        }
        $entry = $existing.plugins[0]
        $expected = './plugins/' + $publicName
        if ($target -eq 'codex') {
            if ($entry.source.source -ne 'local' -or $entry.source.path -ne $expected) { throw 'Preserving a customized PlugLayer source.' }
        } else {
            if ($entry.source -ne $expected) { throw 'Preserving a customized PlugLayer source.' }
            $entry.version = $version
        }
        $Value = $existing
    }
    Write-Json $Path $Value
}
function Verify-PublicRegistration {
    $result = Capture-Native @('plugin','list')
    if ($result.exitCode -ne 0) { throw 'Could not verify PlugLayer registration.' }
    $rows = @($result.output -split "`n" | Where-Object { $_ -match '^pluglayer-codex-plugin@' })
    $expected = '^pluglayer-codex-plugin@pluglayer\s+installed,\s+enabled\s+' + [regex]::Escape($version) + '\s+'
    if ($rows.Count -ne 1 -or $rows[0] -notmatch $expected) { throw 'PlugLayer setup is incomplete: duplicate registration, inactive plugin or unexpected version. Preserve shared catalogs and resolve it through the native plugin manager.' }
    Write-Host $rows[0]
}
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
    $marketName = 'pluglayer'
    if ($target -eq 'codex' -or $target -eq 'claude-code') {
        $marketplace = Join-Path (Join-Path $HOME '.pluglayer\marketplaces') $target
        $catalogDir = if ($target -eq 'codex') { '.agents\plugins' } else { '.claude-plugin' }
        New-Item -ItemType Directory -Force -Path (Join-Path $marketplace $catalogDir) | Out-Null
        $publicName = if ($target -eq 'codex') { 'pluglayer-codex-plugin' } else { 'pluglayer' }
        $dest = Join-Path (Join-Path $marketplace 'plugins') $publicName
        $managed = Join-Path (Join-Path $HOME '.pluglayer\plugin-state') ($target + '-canonical')
        $manifestPath = Join-Path $dest $(if ($target -eq 'codex') { 'plugin.json' } else { '.claude-plugin\plugin.json' })
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $current = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            if ([Version]$current.version -gt [Version]$version) { $version = $current.version; $package = $dest; Say "Keeping the newer installed PlugLayer $version package." }
        }
        if ((Test-Path -LiteralPath $dest) -and !(Assert-Same $dest $package)) {
            if (!(Assert-Same $dest $managed)) { throw "Preserving user-edited plugin: $dest" }
            Remove-Item -LiteralPath $dest -Recurse -Force
        }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest),(Split-Path $managed) | Out-Null
        if (!(Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $package -Destination $dest -Recurse }
        if (Test-Path -LiteralPath $managed) { Remove-Item -LiteralPath $managed -Recurse -Force }
        Copy-Item -LiteralPath $package -Destination $managed -Recurse
        if ($target -eq 'codex') { $catalog = @{ name=$marketName; interface=@{displayName='PlugLayer'}; plugins=@(@{name=$publicName;source=@{source='local';path='./plugins/pluglayer-codex-plugin'};policy=@{installation='AVAILABLE';authentication='ON_INSTALL'};category='Developer Tools'}) }; Write-PublicCatalog (Join-Path (Join-Path $marketplace $catalogDir) 'marketplace.json') $catalog; Register-PublicMarketplace; Run $cli @('plugin','add',($publicName + '@' + $marketName)) }
        else { $catalog = @{ name=$marketName; owner=@{name='PlugLayer'}; plugins=@(@{name=$publicName;source='./plugins/pluglayer';version=$version}) }; Write-PublicCatalog (Join-Path (Join-Path $marketplace $catalogDir) 'marketplace.json') $catalog; Register-PublicMarketplace; Run $cli @('plugin','install',($publicName + '@' + $marketName),'--scope','user'); Run $cli @('plugin','update',($publicName + '@' + $marketName),'--scope','user') }
        Migrate-PublicCatalogs
        if ($target -eq 'codex') { Verify-PublicRegistration } else { Run $cli @('plugin','list') }
    } elseif ($target -eq 'cursor') {
        $dest = Join-Path $HOME '.cursor\plugins\local\pluglayer-cursor-plugin'; $managed = Join-Path $HOME ('.pluglayer\plugin-state\cursor-' + $environmentId)
        if ((Test-Path -LiteralPath $dest) -and !(Assert-Same $dest $package)) { if (!(Assert-Same $dest $managed)) { throw "Preserving user-edited Cursor plugin: $dest. Resolve it using the prompt option." }; Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest),(Split-Path $managed) | Out-Null; if (!(Test-Path $dest)) { Copy-Item $package $dest -Recurse }; if (Test-Path $managed) { Remove-Item $managed -Recurse -Force }; Copy-Item $package $managed -Recurse; Say 'Cursor loads the complete local plugin. Reload any open Cursor window.'
    } else { Run $cli @('plugin','install',$package); Run $cli @('plugin','list') }
    if ($installedUrl) { try { Invoke-RestMethod -Method Post -Uri $installedUrl | Out-Null } catch { Write-Warning 'Package installed; portal status could not refresh.' } }
    Say "4/4 · PlugLayer $version installed in $label"
    Say "Restart or reload $label if the plugin is not visible in your current session."
    Say "Connect PlugLayer through $label's native plugin connection UI when needed."
} catch { try { Invoke-RestMethod -Method Post -Uri $failureUrl | Out-Null } catch {}; throw } finally { if (Test-Path $work) { Remove-Item $work -Recurse -Force } }
