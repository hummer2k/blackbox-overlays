<#
.SYNOPSIS
  Renders the Blackbox plugin's menu icon (Plugin\Blackbox.Plugin\sdkmenuicon.png).

.DESCRIPTION
  SimHub wants a single-colour icon (it tints it for its light/dark menu), so the shape is
  drawn in black on transparent: a rounded black-box panel with three relative rows, the
  middle one filled like the highlighted player row. Rendered 8x supersampled, then reduced
  to 48x48 with high-quality filtering.
#>
param([string]$OutFile = (Join-Path (Split-Path (Split-Path $PSScriptRoot)) 'Plugin\Blackbox.Plugin\sdkmenuicon.png'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$size = 48; $ss = 8; $S = $size * $ss
function New-RoundRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); $p
}
$big = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
$ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Black)
$u = $ss   # 1 icon pixel

# panel outline (3px stroke, radius 8)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), (3 * $u)
$g.DrawPath($pen, (New-RoundRect (3.5 * $u) (6.5 * $u) (41 * $u) (35 * $u) (8 * $u)))

# rows: position cell + name bar + gap bar; middle row = highlighted player row (filled)
$rows = @(13, 21.5, 30)
foreach ($i in 0..2) {
  $y = $rows[$i] * $u
  if ($i -eq 1) {
    $g.FillPath($ink, (New-RoundRect (8 * $u) ($y - 0.5 * $u) (32 * $u) (6 * $u) (2 * $u)))
  } else {
    $g.FillPath($ink, (New-RoundRect (9 * $u) $y (5 * $u) (5 * $u) (1.5 * $u)))     # position
    $g.FillPath($ink, (New-RoundRect (16 * $u) $y (14 * $u) (5 * $u) (1.5 * $u)))   # name
    $g.FillPath($ink, (New-RoundRect (32 * $u) $y (7 * $u) (5 * $u) (1.5 * $u)))    # gap
  }
}
$g.Dispose()

$icon = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2 = [System.Drawing.Graphics]::FromImage($icon)
$g2.InterpolationMode = 'HighQualityBicubic'; $g2.PixelOffsetMode = 'HighQuality'; $g2.CompositingQuality = 'HighQuality'
$g2.Clear([System.Drawing.Color]::Transparent)
$g2.DrawImage($big, 0, 0, $size, $size)
$g2.Dispose(); $big.Dispose()
$icon.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png); $icon.Dispose()
$OutFile
