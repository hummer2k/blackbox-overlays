<#
.SYNOPSIS
  Fails unless the release tag (v<version>) matches the plugin version and Versions.json.
.EXAMPLE
  .\tools\ci\Test-ReleaseVersion.ps1 -Tag v1.1
#>
param([Parameter(Mandatory)] [string]$Tag)
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot)
if ($Tag -notmatch '^v(\d+(\.\d+){1,3})$') { throw "Tag '$Tag' must look like v1.2 or v1.2.3" }
$version = $Matches[1]

$cs = Get-Content (Join-Path $repo 'Plugin\Blackbox.Plugin\Version.cs') -Raw
$current = [regex]::Match($cs, 'CurrentVersion\s*=\s*"([^"]+)"').Groups[1].Value
$beta    = [regex]::Match($cs, 'BetaVersion\s*=\s*"([^"]*)"').Groups[1].Value
$json    = (Get-Content (Join-Path $repo 'Versions.json') -Raw | ConvertFrom-Json).plugin

$errors = @()
if ($current -ne $version) { $errors += "Version.cs CurrentVersion is '$current'" }
if ($beta)                 { $errors += "Version.cs BetaVersion is '$beta' (must be empty for a release)" }
if ($json -ne $version)    { $errors += "Versions.json plugin is '$json'" }
if ($errors) { throw "Tag $Tag (version $version) doesn't match:`n - " + ($errors -join "`n - ") }
"Version $version is consistent"
