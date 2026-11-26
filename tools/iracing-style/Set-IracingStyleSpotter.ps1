<#
.SYNOPSIS
  Restyles benofficial2's "iRacing Spotter" overlay in the look of the iRacing black boxes.

.DESCRIPTION
  - The two columns become black-box panels: top-to-bottom gradient, 1px border, radius 8,
    opacity = the Spotter's 'Background Opacity' setting.
  - The side-by-side bars use iRacing yellow (#FFCC00) with a small radius.
  - The blind spot warning triangle is recoloured to the same yellow and dark grey.
  - The rejoin helper gets the black-box border/radius and the Inter font.
  Normally run by tools\Build-Overlays.ps1 (upstream export -> this script -> Blackbox rebranding).

.EXAMPLE
  .\tools\Build-Overlays.ps1
#>
param(
  [Parameter(Mandatory)] [string]$SourceDir,
  [Parameter(Mandatory)] [string]$TargetDir,
  [string]$Font = 'Inter'
)
. (Join-Path $PSScriptRoot 'IracingStyle.Common.ps1')

$SourceDir = (Resolve-Path $SourceDir).Path
if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory $TargetDir | Out-Null }
$TargetDir = (Resolve-Path $TargetDir).Path
$name = 'benofficial2 - iRacing Spotter'
$mainFile = "$name.djson"

if ([IO.File]::ReadAllText((Join-Path $SourceDir $mainFile)).Contains('"Spotter Panel Left"')) {
  throw 'SourceDir already contains the iRacing style - point it at the original benofficial2 files.'
}
Initialize-Target $SourceDir $TargetDir $mainFile
$mainPath = Join-Path $TargetDir $mainFile
$main = Read-Dash $mainPath

# Spotter.BackgroundOpacity is a Blackbox addition to the plugin (upstream has no spotter opacity)
$opacityJs = "return isnull(`$prop('benofficial2.Spotter.BackgroundOpacity'), 60)"
$widthNc   = '([benofficial2.Spotter.Width] + [benofficial2.Spotter.Border] * 2)'
$heightNc  = '([benofficial2.Spotter.Height] + [variable.borderMax] * 2)'   # parenthesised: used as a factor in the shade bands
$sides = [ordered]@{
  Left  = '250 - [variable.spacing]'
  Right = '462 + [variable.spacing] - [benofficial2.Spotter.Width] - [benofficial2.Spotter.Border] * 2'
}

$root    = @($main['Screens'][0]['Items']) | Where-Object { $_['Name'] -eq 'Visible' }
$spotter = Get-Child $root 'Spotter'
foreach ($side in $sides.Keys) {
  $grp = Get-Child $spotter "Spotter$side"
  $bg  = Get-Child $grp "Background$side"
  $bar = Get-Child $grp "Rectangle$side"
  if (-not $bg -or -not $bar) { throw "Spotter${side}: unexpected structure" }

  # column: black-box panel instead of the opaque rounded rectangle with a thick black border
  $panel = New-PanelChrome $opacityJs $widthNc $heightNc $sides[$side] "Spotter Panel $side"
  $list = New-Object System.Collections.ArrayList
  foreach ($c in @($grp['Childrens'])) { if ($c -eq $bg) { [void]$list.Add($panel) } else { [void]$list.Add($c) } }
  $grp['Childrens'] = $list.ToArray()

  # bar: iRacing yellow, small radius like the cells of the other boxes
  $bar['BackgroundColor'] = $Yellow
  $bar['BorderStyle'] = New-Radius 4 4 4 4
}

# rejoin helper: keep its green..red colour, black-box border and radius, Inter
$rejoin = Get-Child $root 'Rejoin Helper'
$rbg = Get-Child $rejoin 'Background'
$bs = New-Radius 4 4 4 4
$bs['BorderColor'] = '#09FFFFFF'; $bs['BorderTop'] = 1; $bs['BorderBottom'] = 1; $bs['BorderLeft'] = 1; $bs['BorderRight'] = 1
$rbg['BorderStyle'] = $bs
Set-Fonts @{ Childrens = @($main['Screens'][0]['Items']) }

Write-Dash $mainPath $main
'Spotter restyled'

# blind spot triangle: yellow -> iRacing yellow, black -> panel dark (antialiasing and alpha kept)
Add-Type -AssemblyName System.Drawing, System.IO.Compression, System.IO.Compression.FileSystem
$ress = Join-Path $TargetDir "$mainFile.ressources"
$zip = [IO.Compression.ZipFile]::Open($ress, [IO.Compression.ZipArchiveMode]::Update)
try {
  $entry = $zip.GetEntry('Blind Spot Monitor.png'); if (-not $entry) { throw 'Blind Spot Monitor.png not found' }
  $ms = New-Object IO.MemoryStream; $s = $entry.Open(); $s.CopyTo($ms); $s.Dispose()
  $src = New-Object System.Drawing.Bitmap $ms
  $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $dark = [System.Drawing.ColorTranslator]::FromHtml('#16161C'); $yel = [System.Drawing.ColorTranslator]::FromHtml('#FFCC00')
  for ($x = 0; $x -lt $src.Width; $x++) {
    for ($y = 0; $y -lt $src.Height; $y++) {
      $p = $src.GetPixel($x, $y)
      if ($p.A -eq 0) { $bmp.SetPixel($x, $y, [System.Drawing.Color]::Transparent); continue }
      $t = [Math]::Min(1.0, $p.G / 254.0)                          # 0 = black outline/mark, 1 = yellow
      $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A,
        [int]($dark.R + ($yel.R - $dark.R) * $t), [int]($dark.G + ($yel.G - $dark.G) * $t), [int]($dark.B + ($yel.B - $dark.B) * $t)))
    }
  }
  $src.Dispose(); $ms.Dispose()
  $entry.Delete()
  $out = $zip.CreateEntry('Blind Spot Monitor.png').Open()
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $out.Dispose(); $bmp.Dispose()
} finally { $zip.Dispose() }
'Blind spot icon recoloured'
