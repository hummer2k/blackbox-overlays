<#
.SYNOPSIS
  Generates iRacing-style tyre compound icons (dark disc, coloured ring, white letter) into tools\iracing-style\images.
  Currently: wet tyre with iRacing's dark blue ring (#0159CF, measured).
#>
param([string]$OutDir = (Join-Path $PSScriptRoot 'images'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory $OutDir | Out-Null }

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $PSScriptRoot 'fonts\Inter-Bold.ttf'))
$family = $fonts.Families[0]

function New-TyreIcon([string]$file, [string]$letter, [string]$ringHex) {
  $size = 200
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.Clear([System.Drawing.Color]::Transparent)
  $ring = [System.Drawing.ColorTranslator]::FromHtml($ringHex)
  $fill = [System.Drawing.ColorTranslator]::FromHtml('#16161C')
  $stroke = 18.0                                        # ~2px at 24px row height, like iRacing
  $inset = $stroke / 2 + 2
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $fill), $inset, $inset, $size - 2 * $inset, $size - 2 * $inset)
  $g.DrawEllipse((New-Object System.Drawing.Pen $ring, $stroke), $inset, $inset, $size - 2 * $inset, $size - 2 * $inset)
  $font = New-Object System.Drawing.Font $family, 104, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $g.DrawString($letter, $font, (New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#F2F2F3'))),
                (New-Object System.Drawing.RectangleF 0, 4, $size, $size), $fmt)
  $g.Dispose()
  $path = Join-Path $OutDir $file
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  $path
}

New-TyreIcon 'Tire Wet iRacing.png' 'W' '#0159CF'
