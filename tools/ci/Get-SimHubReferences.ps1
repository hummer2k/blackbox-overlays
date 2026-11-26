<#
.SYNOPSIS
  Provides SimHub's DLLs for building the plugin on a machine without SimHub (CI).

.DESCRIPTION
  Downloads SimHub's release zip from github.com/SHWotever/SimHub, installs it silently into a temp
  folder and copies all DLLs into -OutDir. (innoextract can't read SimHub's Inno Setup 6.4 installer.)
  The DLLs are only used as compile references; they are not redistributed.

.EXAMPLE
  .\tools\ci\Get-SimHubReferences.ps1 -Version 9.13.8 -OutDir simhub-ref
#>
param(
  [Parameter(Mandatory)] [string]$Version,
  [Parameter(Mandatory)] [string]$OutDir
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$work = Join-Path ([IO.Path]::GetTempPath()) "simhub-$Version"
New-Item -ItemType Directory $work -Force | Out-Null
$zip = Join-Path $work "SimHub.$Version.zip"
$url = "https://github.com/SHWotever/SimHub/releases/download/$Version/SimHub.$Version.zip"
"Downloading $url"
Invoke-WebRequest $url -OutFile $zip -UseBasicParsing
Expand-Archive $zip (Join-Path $work 'zip') -Force
$setup = Get-ChildItem (Join-Path $work 'zip') -Recurse -Filter 'SimHubSetup*.exe' | Select-Object -First 1
if (-not $setup) { throw "No SimHubSetup*.exe in $zip" }

"Installing $($setup.Name) silently"
$dir = Join-Path $work 'install'
$p = Start-Process $setup.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$dir`"" -Wait -PassThru
if ($p.ExitCode) { throw "Installer exit code $($p.ExitCode)" }
Get-Process SimHubWPF -ErrorAction SilentlyContinue | Stop-Process -Force
$marker = Get-ChildItem $dir -Recurse -Filter 'SimHub.Plugins.dll' | Select-Object -First 1
if (-not $marker) { throw 'SimHub.Plugins.dll not found after install' }

New-Item -ItemType Directory $OutDir -Force | Out-Null
Copy-Item (Join-Path $marker.DirectoryName '*.dll') $OutDir -Force
"Copied $((Get-ChildItem $OutDir -Filter *.dll).Count) DLLs from $($marker.DirectoryName) to $OutDir"
exit 0
