<#
.SYNOPSIS
  Fails unless the release tag is semver (vMAJOR.MINOR.PATCH) and matches the plugin version, every entry of
  Versions.json and the version stamped into the overlays.
.EXAMPLE
  .\tools\ci\Test-ReleaseVersion.ps1 -Tag v1.1.0
#>
param([Parameter(Mandatory)] [string]$Tag)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot)
if ($Tag -notmatch '^v((0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*))$') { throw "Tag '$Tag' must be a semantic version like v1.2.3" }
$version = $Matches[1]

$cs = Get-Content (Join-Path $repo 'Plugin\Blackbox.Plugin\Version.cs') -Raw
$current = [regex]::Match($cs, 'CurrentVersion\s*=\s*"([^"]+)"').Groups[1].Value
$beta    = [regex]::Match($cs, 'BetaVersion\s*=\s*"([^"]*)"').Groups[1].Value
$json    = Get-Content (Join-Path $repo 'Versions.json') -Raw | ConvertFrom-Json

$errors = @()
if ($current -ne $version) { $errors += "Version.cs CurrentVersion is '$current'" }
if ($beta)                 { $errors += "Version.cs BetaVersion is '$beta' (must be empty for a release)" }
# plugin and overlays share one version
foreach ($p in $json.PSObject.Properties) {
  if ($p.Value -ne $version) { $errors += "Versions.json $($p.Name) is '$($p.Value)'" }
}
foreach ($dash in Get-ChildItem (Join-Path $repo 'Overlays') -Recurse -Filter *.djson) {
  foreach ($m in [regex]::Matches([IO.File]::ReadAllText($dash.FullName), "g_VersionNumber = (?:'|\\u0027)([^'\\]+)")) {
    if ($m.Groups[1].Value -ne $version) { $errors += "$($dash.Name) g_VersionNumber is '$($m.Groups[1].Value)' (run tools\Build-Overlays.ps1)" }
  }
}
if ($errors) { throw "Tag $Tag (version $version) doesn't match:`n - " + ($errors -join "`n - ") }
"Version $version is consistent"
