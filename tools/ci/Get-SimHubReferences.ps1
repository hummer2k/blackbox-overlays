<#
.SYNOPSIS
  Provides SimHub's DLLs for building the plugin on a machine without SimHub (CI).

.DESCRIPTION
  Downloads SimHub's release zip from github.com/SHWotever/SimHub, extracts the Inno Setup installer
  with innoextract (installed via Chocolatey if missing) and copies all DLLs of the app into -OutDir.
  Falls back to a silent install into a temp folder if innoextract can't read the installer.
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
"Installer: $($setup.Name)"

$app = $null
try {
  if (-not (Get-Command innoextract -ErrorAction SilentlyContinue)) {
    choco install innoextract -y --no-progress | Out-Host
    $env:Path += ';C:\ProgramData\chocolatey\bin'
  }
  $ex = Join-Path $work 'extract'
  innoextract --silent --extract --output-dir $ex $setup.FullName
  if ($LASTEXITCODE) { throw "innoextract exit code $LASTEXITCODE" }
  $marker = Get-ChildItem $ex -Recurse -Filter 'SimHub.Plugins.dll' | Select-Object -First 1
  if ($marker) { $app = $marker.DirectoryName }
} catch { Write-Warning "innoextract failed: $_" }

if (-not $app) {
  'Falling back to a silent install'
  $dir = Join-Path $work 'install'
  $p = Start-Process $setup.FullName -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/DIR=`"$dir`"" -Wait -PassThru
  if ($p.ExitCode) { throw "Installer exit code $($p.ExitCode)" }
  Get-Process SimHubWPF -ErrorAction SilentlyContinue | Stop-Process -Force
  $marker = Get-ChildItem $dir -Recurse -Filter 'SimHub.Plugins.dll' | Select-Object -First 1
  if (-not $marker) { throw 'SimHub.Plugins.dll not found after install' }
  $app = $marker.DirectoryName
}

New-Item -ItemType Directory $OutDir -Force | Out-Null
Copy-Item (Join-Path $app '*.dll') $OutDir -Force
"Copied $((Get-ChildItem $OutDir -Filter *.dll).Count) DLLs from $app to $OutDir"
