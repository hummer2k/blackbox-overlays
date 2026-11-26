<#
.SYNOPSIS
  Installs the Blackbox overlays (and the plugin, if built) into SimHub.

.DESCRIPTION
  - Overlays\Blackbox - *          -> <SimHub>\DashTemplates
  - fonts shipped in _SHFonts      -> <SimHub>\DashFonts (only missing ones)
  - Images\{CarLogos,Flairs,Icons} -> <SimHub>\ImageLibrary\Blackbox
  - Blackbox.Plugin.dll            -> <SimHub>  (Release build, see README)

  -MigrateFromBenofficial2 additionally (once, when switching over):
  - copies the benofficial2 plugin settings to Blackbox.*.json (existing Blackbox settings are kept),
  - points the overlay layouts (window positions/sizes) at the Blackbox overlays,
  - moves benofficial2.Plugin.dll and the benofficial2 overlays into <SimHub>\_Backup_benofficial2_<date>.
  Nothing is deleted.

  SimHub must be closed. On the next start SimHub asks to enable the new Blackbox plugin.

.EXAMPLE
  .\tools\Install-Blackbox.ps1 -MigrateFromBenofficial2
#>
param(
  [string]$SimHubDir,
  [string]$PluginDll,
  [switch]$SkipPlugin,
  [switch]$MigrateFromBenofficial2
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
. (Join-Path $PSScriptRoot 'Blackbox.Branding.ps1')

if (-not $SimHubDir) {
  $SimHubDir = (Get-ItemProperty 'HKCU:\SOFTWARE\SimHub' -Name InstallDirectory -ErrorAction SilentlyContinue).InstallDirectory
  if (-not $SimHubDir) { $SimHubDir = 'C:\Program Files (x86)\SimHub' }
}
if (-not (Test-Path (Join-Path $SimHubDir 'SimHubWPF.exe'))) { throw "SimHub not found in '$SimHubDir' (use -SimHubDir)" }
$exe = (Resolve-Path (Join-Path $SimHubDir 'SimHubWPF.exe')).Path
if (Get-Process SimHubWPF -ErrorAction SilentlyContinue | Where-Object { -not $_.Path -or $_.Path -eq $exe }) {
  throw 'SimHub is running - please close it first.'
}
if (-not $PluginDll) {
  # release zip: DLL next to Install.cmd; repository: local Release build
  $PluginDll = Join-Path $repo 'Blackbox.Plugin.dll'
  if (-not (Test-Path $PluginDll)) { $PluginDll = Join-Path $repo 'Plugin\Blackbox.Plugin\bin\Release\Blackbox.Plugin.dll' }
}
if ($MigrateFromBenofficial2 -and ($SkipPlugin -or -not (Test-Path $PluginDll))) {
  throw "-MigrateFromBenofficial2 removes the benofficial2 plugin, so the Blackbox plugin must be built first ($PluginDll)."
}
"SimHub: $SimHubDir"

# ---- overlays ----
$dashDir = Join-Path $SimHubDir 'DashTemplates'
$fontDir = Join-Path $SimHubDir 'DashFonts'
foreach ($name in $BlackboxOverlays.Values) {
  $src = Join-Path $repo "Overlays\$name"
  if (-not (Test-Path $src)) { throw "Missing $src - run tools\Build-Overlays.ps1 first" }
  $dst = Join-Path $dashDir $name
  if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
  Copy-Item $src $dst -Recurse
  foreach ($ttf in Get-ChildItem (Join-Path $src '_SHFonts') -Filter *.ttf -ErrorAction SilentlyContinue) {
    $t = Join-Path $fontDir $ttf.Name
    if (-not (Test-Path $t)) { Copy-Item $ttf.FullName $t }
  }
  "Overlay:  $name"
}

# ---- image library ----
$lib = Join-Path $SimHubDir "ImageLibrary\$BlackboxImageLibrary"
foreach ($sub in 'CarLogos', 'Flairs', 'Icons') {
  $d = Join-Path $lib $sub
  if (-not (Test-Path $d)) { New-Item -ItemType Directory $d -Force | Out-Null }
  Copy-Item (Join-Path $repo "Images\$sub\*") $d -Force
}
"Images:   $lib"

# ---- plugin ----
if (-not $SkipPlugin) {
  if (Test-Path $PluginDll) { Copy-Item $PluginDll $SimHubDir -Force; "Plugin:   $(Split-Path $PluginDll -Leaf)" }
  else { Write-Warning "Plugin not built yet ($PluginDll) - overlays installed, plugin skipped. See README > Building the plugin." }
}

# ---- one-time switch from benofficial2 ----
if ($MigrateFromBenofficial2) {
  $backup = Join-Path $SimHubDir ("_Backup_benofficial2_" + (Get-Date -Format 'yyyy-MM-dd_HHmm'))
  New-Item -ItemType Directory $backup | Out-Null

  $common = Join-Path $SimHubDir 'PluginsData\Common'
  # only the settings of modules the Blackbox plugin still has
  $kept = 'GeneralSettings_3.1', 'RelativeSettings', 'StandingsSettings', 'SpotterSettings', 'BlindSpotMonitorSettings',
          'RejoinHelperSettings', 'HighlightedDriverSettings', 'PitlaneHelperSettings',
          'PrecipitationSettings', 'TrackWetnessSettings', 'WindSettings'
  foreach ($f in Get-ChildItem $common -Filter 'benofficial2.*.json' -ErrorAction SilentlyContinue |
                 Where-Object { $kept -contains $_.BaseName.Substring('benofficial2.'.Length) }) {
    $t = Join-Path $common ("$BlackboxPluginPrefix." + $f.Name.Substring('benofficial2.'.Length))
    if (-not (Test-Path $t)) { Copy-Item $f.FullName $t; "Settings: $($f.Name) -> $(Split-Path $t -Leaf)" }
  }

  foreach ($lay in Get-ChildItem (Join-Path $SimHubDir 'OverlayLayouts') -Filter *.olayout -ErrorAction SilentlyContinue) {
    $t = [IO.File]::ReadAllText($lay.FullName)
    $n = $t; foreach ($old in $BlackboxOverlays.Keys) { $n = $n.Replace($old, $BlackboxOverlays[$old]) }
    if ($n -ne $t) {
      Copy-Item $lay.FullName (Join-Path $backup $lay.Name)
      [IO.File]::WriteAllText($lay.FullName, $n, (New-Object Text.UTF8Encoding $false))
      "Layout:   $($lay.Name)"
    }
  }

  $oldDll = Join-Path $SimHubDir 'benofficial2.Plugin.dll'
  if (Test-Path $oldDll) { Move-Item $oldDll $backup; 'Moved:    benofficial2.Plugin.dll' }
  $oldDashes = Join-Path $backup 'DashTemplates'
  foreach ($d in Get-ChildItem $dashDir -Directory -Filter 'benofficial2 - *') {
    if (-not (Test-Path $oldDashes)) { New-Item -ItemType Directory $oldDashes | Out-Null }
    Move-Item $d.FullName $oldDashes; "Moved:    $($d.Name)"
  }
  "Backup:   $backup"
}
'Done. Start SimHub and enable the Blackbox plugin when asked.'
