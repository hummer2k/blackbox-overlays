<#
.SYNOPSIS
  Builds the Blackbox overlays in Overlays\ from benofficial2's original overlays.

.DESCRIPTION
  1. Exports the original overlays from benofficial2's repository at -UpstreamRef (git archive,
     nothing in the working tree is touched).
  2. Applies the iRacing style (tools\iracing-style\Set-IracingStyle*.ps1).
  3. Rebrands them for the Blackbox plugin: folder/file names, Blackbox.* properties,
     Blackbox image library, update check URL.
  4. Replaces Overlays\Blackbox - * with the result.

  The pinned upstream commit lives in tools\upstream-ref.txt. To pick up upstream changes:
    git fetch upstream
    .\tools\Build-Overlays.ps1 -UpstreamRef upstream/master
  and, if the result looks good, write the new commit hash into tools\upstream-ref.txt.

.EXAMPLE
  .\tools\Build-Overlays.ps1
#>
param(
  [string]$UpstreamRef,
  [string]$OutDir
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $repo 'Overlays' }
if (-not $UpstreamRef) { $UpstreamRef = (Get-Content (Join-Path $PSScriptRoot 'upstream-ref.txt') -TotalCount 1).Trim() }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $env:Path += ';C:\Program Files\Git\cmd' }
. (Join-Path $PSScriptRoot 'Blackbox.Branding.ps1')

$commit = git -C $repo rev-parse --verify --quiet "$UpstreamRef^{commit}"
if (-not $commit) { throw "Unknown upstream ref '$UpstreamRef' (run 'git fetch upstream' first?)" }
"Upstream: $UpstreamRef ($commit)"

# ---- 1. export the originals ----
$work = Join-Path ([IO.Path]::GetTempPath()) ("blackbox-build-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory $work | Out-Null
try {
  $needed = @($BlackboxOverlays.Keys) + @($WeatherSources)   # weather widgets feed the Relative header
  $zip = Join-Path $work 'upstream.zip'
  git -C $repo archive --format=zip -o $zip $commit -- @($needed | ForEach-Object { "Overlays/$_" })
  if ($LASTEXITCODE) { throw 'git archive failed' }
  Expand-Archive $zip (Join-Path $work 'src')
  $src = Join-Path $work 'src\Overlays'

  # ---- 2. iRacing style (in place, on the upstream layout) ----
  $style = Join-Path $PSScriptRoot 'iracing-style'
  & (Join-Path $style 'Set-IracingStyleRelative.ps1')  -SourceDir (Join-Path $src 'benofficial2 - iRacing Relative') `
                                                       -TargetDir (Join-Path $src 'benofficial2 - iRacing Relative') | Out-Host
  & (Join-Path $style 'Set-IracingStyleStandings.ps1') -SourceDir (Join-Path $src 'benofficial2 - iRacing Multi-Class Standings') `
                                                       -TargetDir (Join-Path $src 'benofficial2 - iRacing Multi-Class Standings') | Out-Host
  & (Join-Path $style 'Set-IracingStyleSpotter.ps1')   -SourceDir (Join-Path $src 'benofficial2 - iRacing Spotter') `
                                                       -TargetDir (Join-Path $src 'benofficial2 - iRacing Spotter') | Out-Host

  # ---- 3. + 4. rebrand into Overlays\ ----
  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory $OutDir | Out-Null }
  foreach ($old in $BlackboxOverlays.Keys) {
    $new = $BlackboxOverlays[$old]
    $dst = Join-Path $OutDir $new
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item (Join-Path $src $old) $dst -Recurse
    Convert-ToBlackbox $dst
    "Built:    $dst"
  }
} finally {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
