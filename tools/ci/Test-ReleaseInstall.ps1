<#
.SYNOPSIS
  Unpacks the release zip and runs its installer against an empty fake SimHub folder, the way a user would
  (Install.cmd -> tools\Install-Blackbox.ps1, without the repository around it). Fails if anything is missing.
.EXAMPLE
  .\tools\ci\Test-ReleaseInstall.ps1 -Zip dist\Blackbox-Overlays-1.0.2.zip
#>
param([Parameter(Mandatory)] [string]$Zip)
$ErrorActionPreference = 'Stop'
$work = Join-Path ([IO.Path]::GetTempPath()) ("blackbox-install-test-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
$pkg = Join-Path $work 'zip'; $simhub = Join-Path $work 'SimHub'
try {
  Expand-Archive $Zip $pkg
  New-Item -ItemType Directory $simhub | Out-Null
  New-Item -ItemType File (Join-Path $simhub 'SimHubWPF.exe') | Out-Null   # the installer only checks that it exists

  # same call as Install.cmd, in a fresh process so nothing from this session leaks in
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $pkg 'tools\Install-Blackbox.ps1') -SimHubDir $simhub
  if ($LASTEXITCODE) { throw "Install-Blackbox.ps1 from the zip failed (exit code $LASTEXITCODE)" }

  $expected = @('Blackbox.Plugin.dll',
                'DashTemplates\Blackbox - Relative\Blackbox - Relative.djson',
                'DashTemplates\Blackbox - Multi-Class Standings\Blackbox - Multi-Class Standings.djson',
                'DashTemplates\Blackbox - Spotter\Blackbox - Spotter.djson',
                'ImageLibrary\Blackbox\CarLogos', 'ImageLibrary\Blackbox\Flairs', 'ImageLibrary\Blackbox\Icons')
  $missing = $expected | Where-Object { -not (Test-Path (Join-Path $simhub $_)) }
  if ($missing) { throw "Installed from the zip, but missing:`n - " + ($missing -join "`n - ") }
  if (-not (Get-ChildItem (Join-Path $simhub 'DashFonts') -Filter *.ttf -ErrorAction SilentlyContinue)) { throw 'No fonts installed to DashFonts' }
  'Release zip installs cleanly'
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
