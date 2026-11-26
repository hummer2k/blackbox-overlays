# Shared names and the rebranding step (benofficial2 overlay -> Blackbox overlay).
# Dot-source it:  . (Join-Path $PSScriptRoot 'Blackbox.Branding.ps1')

# upstream overlay folder -> Blackbox overlay folder
$BlackboxOverlays = [ordered]@{
  'benofficial2 - iRacing Relative'              = 'Blackbox - Relative'
  'benofficial2 - iRacing Multi-Class Standings' = 'Blackbox - Multi-Class Standings'
  'benofficial2 - iRacing Spotter'               = 'Blackbox - Spotter'
}
# upstream widgets the Relative header takes its icons and wind formula from (not shipped themselves)
$WeatherSources = @('benofficial2 - iRacing Precipitation', 'benofficial2 - iRacing Track Wetness', 'benofficial2 - iRacing Wind')

$BlackboxPluginPrefix = 'Blackbox'   # = plugin class name = SimHub property prefix
$BlackboxImageLibrary = 'Blackbox'   # ImageLibrary\Blackbox\{CarLogos,Flairs,Icons}
$BlackboxVersionsUrl  = 'https://raw.githubusercontent.com/hummer2k/blackbox-overlays/main/Versions.json'
$BlackboxReleasesUrl  = 'https://github.com/hummer2k/blackbox-overlays/releases'
# One version for plugin and overlays: the plugin's CurrentVersion (semver) is stamped into every overlay
$BlackboxVersion = [regex]::Match([IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot) 'Plugin\Blackbox.Plugin\Version.cs')),
                                  'CurrentVersion\s*=\s*"([^"]+)"').Groups[1].Value
if (-not $BlackboxVersion) { throw 'CurrentVersion not found in Plugin\Blackbox.Plugin\Version.cs' }

# Rewrites one text in place: overlay names, plugin properties, image library, author, update URL.
# Copyright headers ("benofficial2's Official Overlays", "Copyright (C) ... benofficial2") are kept on purpose.
function Convert-BlackboxText([string]$t) {
  foreach ($old in $BlackboxOverlays.Keys) { $t = $t.Replace($old, $BlackboxOverlays[$old]) }
  $t = $t.Replace('https://raw.githubusercontent.com/fixfactory/bo2-official-overlays/main/Versions.json', $BlackboxVersionsUrl)
  $t = $t.Replace('Download new version at https://github.com/fixfactory/bo2-official-overlays', "Download new version at $BlackboxReleasesUrl")
  $t = [regex]::Replace($t, "(const g_VersionNumber = (?:'|\\u0027))[^'\\]+((?:'|\\u0027))", "`${1}$BlackboxVersion`${2}")
  $t = $t.Replace('library:benofficial2', "library:$BlackboxImageLibrary")
  $t = $t.Replace('twitch.tv/benofficial2', 'hummer2k (based on benofficial2)')
  $t = $t.Replace('benofficial2 plugin', 'Blackbox plugin')
  # plugin properties: benofficial2.Relative.*, benofficial2.iRacingRunning, ...
  $t = [regex]::Replace($t, 'benofficial2\.(?=[A-Za-z_])', "$BlackboxPluginPrefix.")
  return $t
}

# Rebrands a copied overlay folder: renames files and rewrites the text files.
function Convert-ToBlackbox([string]$dir) {
  foreach ($f in Get-ChildItem $dir -Recurse -File) {
    foreach ($old in $BlackboxOverlays.Keys) {
      if ($f.Name.StartsWith($old)) { $f = Rename-Item $f.FullName ($BlackboxOverlays[$old] + $f.Name.Substring($old.Length)) -PassThru; break }
    }
    if ($f.Name -notmatch '\.(djson|js|metadata|json)$') { continue }
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $t = [Text.Encoding]::UTF8.GetString($bytes); if ($bom) { $t = $t.Substring(1) }
    $n = Convert-BlackboxText $t
    if ($n -ne $t) { [IO.File]::WriteAllText($f.FullName, $n, (New-Object Text.UTF8Encoding $bom)) }
    $left = [regex]::Matches($n, "(?<!based on )benofficial2(?!'s Official Overlays)") |
            Where-Object { $n.Substring([Math]::Max(0, $_.Index - 30), [Math]::Min(30, $_.Index)) -notmatch 'Copyright' }
    if ($left) { Write-Warning "$($f.Name): $(@($left).Count) unconverted 'benofficial2' reference(s)" }
  }
}
