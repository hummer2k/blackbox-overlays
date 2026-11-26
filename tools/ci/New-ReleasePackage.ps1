<#
.SYNOPSIS
  Packs a release zip: plugin DLL, overlays, images, installer script, licence.

.DESCRIPTION
  Layout of Blackbox-Overlays-<version>.zip:
    Install.cmd                       double-click installer (runs tools\Install-Blackbox.ps1)
    Blackbox.Plugin.dll
    Overlays\Blackbox - *\
    Images\{CarLogos,Flairs,Icons}\
    tools\Install-Blackbox.ps1, tools\Blackbox.Branding.ps1
    LICENSE, README.md

.EXAMPLE
  .\tools\ci\New-ReleasePackage.ps1 -Version 1.0 -OutDir dist
#>
param(
  [Parameter(Mandatory)] [string]$Version,
  [string]$OutDir = 'dist',
  [string]$PluginDll
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot)
if (-not $PluginDll) { $PluginDll = Join-Path $repo 'Plugin\Blackbox.Plugin\bin\Release\Blackbox.Plugin.dll' }
if (-not (Test-Path $PluginDll)) { throw "Plugin not built: $PluginDll" }

$name = "Blackbox-Overlays-$Version"
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$stage = Join-Path $OutDir $name
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory (Join-Path $stage 'tools') | Out-Null

Copy-Item $PluginDll $stage
Copy-Item (Join-Path $repo 'Overlays') $stage -Recurse
New-Item -ItemType Directory (Join-Path $stage 'Images') | Out-Null
foreach ($sub in 'CarLogos', 'Flairs', 'Icons') { Copy-Item (Join-Path $repo "Images\$sub") (Join-Path $stage 'Images') -Recurse }
Copy-Item (Join-Path $repo 'tools\Install-Blackbox.ps1'), (Join-Path $repo 'tools\Blackbox.Branding.ps1') (Join-Path $stage 'tools')
Copy-Item (Join-Path $repo 'LICENSE'), (Join-Path $repo 'README.md') $stage
$cmd = "@echo off`r`n" +
       "rem Installs the Blackbox overlays and plugin into SimHub (close SimHub first).`r`n" +
       "rem Pass -MigrateFromBenofficial2 once when switching over from benofficial2's plugin.`r`n" +
       "powershell -NoProfile -ExecutionPolicy Bypass -File ""%~dp0tools\Install-Blackbox.ps1"" %*`r`n" +
       "pause`r`n"
[IO.File]::WriteAllText((Join-Path $stage 'Install.cmd'), $cmd, (New-Object Text.ASCIIEncoding))

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip }
# entries written one by one: Compress-Archive and ZipFile.CreateFromDirectory in Windows PowerShell 5.1
# put '\' into the entry names, which other unzip tools don't treat as folders
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($f in Get-ChildItem $stage -Recurse -File) {
    $entry = $f.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
  }
} finally { $archive.Dispose() }
Remove-Item $stage -Recurse -Force
$zip
