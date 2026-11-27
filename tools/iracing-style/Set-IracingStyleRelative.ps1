<#
.SYNOPSIS
  Restyles benofficial2's "iRacing Relative" overlay to look like the native iRacing (2025 UI) Relative box.

.DESCRIPTION
  Reads the ORIGINAL (unmodified) overlay from -SourceDir and writes the restyled overlay to -TargetDir.
  -SourceDir and -TargetDir may be the same folder, as long as it still contains the original files
  (the script refuses to run twice on already-styled files).

  Normally run by tools\Build-Overlays.ps1 (upstream export -> this script -> Blackbox rebranding).
  The Precipitation / Track Wetness / Wind widgets must be siblings of -SourceDir.

.EXAMPLE
  .\tools\Build-Overlays.ps1
#>
param(
  [Parameter(Mandatory)] [string]$SourceDir,
  [Parameter(Mandatory)] [string]$TargetDir,
  # Inter (SIL OFL) is the closest match to iRacing's UI font. SimHub loads dash fonts from its global DashFonts
  # folder (overlay _SHFonts are copied there when a dash is imported); pass 'Segoe UI' if Inter isn't installed.
  [string]$Font = 'Inter'
)
. (Join-Path $PSScriptRoot 'IracingStyle.Common.ps1')

$SourceDir = (Resolve-Path $SourceDir).Path
if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory $TargetDir | Out-Null }
$TargetDir = (Resolve-Path $TargetDir).Path
$rel = 'benofficial2 - iRacing Relative'

$Shift     = 21          # car number right edge moves from 60 to 81 (room for pos cell + timeline)
$GapExtra  = 14          # extra width for the timing column so it doesn't touch the pit/lap column
$OrigW     = 500         # benofficial2 dashboard width
# extra horizontal space per column (multiples of $ColGap, cumulative from left to right)
$ColSteps  = [ordered]@{ 'Country Flag' = 1; 'DriverName' = 2; 'Black Flag' = 2; 'OutLap' = 2; 'Push To Pass' = 2; 'Car Logo' = 2;
                         'Rating' = 3; 'Last Lap Time' = 4; 'Tire Compound' = 5; 'Pit Status' = 6; 'GapToPlayer' = 7 }
$ColExtra  = 7 * $ColGap + $RatingExtra   # column gaps + the larger rating badge
$Widen     = $Shift + $GapExtra + $ColExtra
$NewW      = $OrigW + $Widen

$idx        = "`$prop('variable.relativeIdx')"
$isPlayer   = "$idx == 0"
$classColor = "isnull(getRelativeProp($idx, 'CarClassColor'), '#FFFFFF')"

Initialize-Target $SourceDir $TargetDir "$rel.djson"

# ---------------- Relative Row ----------------
$rowPath = Join-Path $TargetDir "Relative Row.djson"
$row = Read-Dash $rowPath
$row['BaseHeight'] = $R; $row['BaseWidth'] = $NewW
(Get-Var $row 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
$items = $row['Screens'][0]['Items']
$bg  = $items | Where-Object { $_['Name'] -eq 'Background' }
$hl  = $items | Where-Object { $_['Name'] -eq 'Player Highlight' }
$vis = $items | Where-Object { $_['Name'] -eq 'Visible' }

foreach ($c in @($vis['Childrens'])) { Set-RowHeight $c 20 $R }

# per-row backgrounds caused seams; the panel is drawn once in the main dash
$bg['Visible'] = $false; $bg['Bindings'].Remove('Visible') | Out-Null

Set-PlayerHighlight $hl ("if (!($isPlayer))`r`n`treturn false`r`n" +
                         "if (!isnull(`$prop('benofficial2.Relative.HighlightPlayerRow'), true))`r`n`treturn false`r`n" +
                         "return getRelativeRowVisible($idx)") '[variable.headerWidth] - 2'

# make room for position cell + class timeline: shift everything right of the position
foreach ($c in @($vis['Childrens'])) {
  $hasLeftBinding = $c['Bindings'] -and $c['Bindings'].ContainsKey('Left')
  if ([double]$c['Left'] -ge 20 -or $hasLeftBinding) { Add-ToLeft $c $Shift }
}
# column spacing (the name keeps its width; everything right of it moves along)
foreach ($n in $ColSteps.Keys) { Add-ToLeft (Get-Child $vis $n) ($ColSteps[$n] * $ColGap) }
# larger, outlined rating badge; columns to its right make room
Set-RatingStyle (Get-Child $vis 'Rating')
foreach ($n in 'Last Lap Time', 'Tire Compound', 'Pit Status', 'GapToPlayer') { Add-ToLeft (Get-Child $vis $n) $RatingExtra }
foreach ($n in 'DriverName', 'GapToPlayer', 'Position In Class') { (Get-Child $vis $n)['FontSize'] = $NameSize }
Set-PitPills $vis
Set-IracingTyreIcons $vis
# keep long names clear of the OUT badge (31px) and the black flag (20px)
$blackJs = "(isnull(getRelativeProp($idx, 'SessionFlags'), 0) & (0x00010000 | 0x00080000 | 0x00100000))"
Set-NameBadgeRoom (Get-Child $vis 'DriverName') "(getRelativeProp($idx, 'OutLap') ? 34 : 0) + ($blackJs ? 22 : 0)"

# timing value in the lighter column: starts 4px right of the pit/lap column, right-aligned, fixed-pitch digits
$gapTxt = Get-Child $vis 'GapToPlayer'
Add-ToLeft $gapTxt 4
$gapTxt['HorizontalAlignment'] = 2
$gpad = New-Dict; $gpad['PaddingRight'] = 6; $gapTxt['TextPadding'] = $gpad
Set-TimingMonospace $gapTxt
Set-TimingMonospace (Get-Child $vis 'Last Lap Time')
Set-Nc $gapTxt 'Width' ("[variable.headerWidth] - 1 - (" + (Get-Expr $gapTxt 'Left') + ")")
# player highlight ends before the timing column, like iRacing
Set-Nc $hl 'Width' ("(" + (Get-Expr $gapTxt 'Left') + ") - 3")

# class colour once per row widget; the ~25 timeline items read it via a cheap NCalc binding
Add-Var $row 'classColor' "return $classColor"

$pos = Get-Child $vis 'Position In Class'
$pos['Left'] = [double]$PosLeft; $pos['Width'] = [double]$PosW
Set-Js $pos 'TextColor' "return ($isPlayer) ? '$OnYellow' : getRelativeTextColor($idx);"

# marker shape = class rank (fastest first), taken from the standings' class order (sorted by lap time)
Add-Var $row 'classShape' (@"
const c = getRelativeProp($idx, 'CarClassColor');
for (let i = 0; i < 4; i++) { if (`$prop('benofficial2.Standings.Class0' + i + '.Color') == c) return i % 3; }
return 0;
"@ -replace "`r`n", "`n")
$timeline = New-ClassTimeline '[variable.classColor]' '[variable.classShape]'
Insert-Children $vis 0 (@($timeline | Where-Object { $_['Name'] -like 'Class Glow*' }) + @(New-PosCell $isPlayer) + @($timeline | Where-Object { $_['Name'] -notlike 'Class Glow*' }))

$num = Get-Child $vis 'Number'
$numRight = [double]$num['Left'] + [double]$num['Width'] - 2
$hash = Set-NumberStyle $num "getRelativeProp($idx, 'Number')" $isPlayer '[variable.classColor]' "$numRight"
Insert-Children $vis ([array]::IndexOf(@($vis['Childrens']), $num) + 1) @($hash)

Set-Fonts @{ Childrens = $items }
Write-Dash $rowPath $row
"Relative Row restyled"

# ---------------- Relative main ----------------
$mainPath = Join-Path $TargetDir "$rel.djson"
$main = Read-Dash $mainPath
$layer = $main['Screens'][0]['Items'][0]
$header = Get-Child $layer 'Header'
$footer = Get-Child $layer 'Footer'
$origFooter = Copy-Deep $footer
$origHeader = Copy-Deep $header

# widths: dashboard and min content width grow by Shift+GapExtra; the user's width setting is honoured
# (+Shift+GapExtra) so the name column keeps its original size
(Get-Var $main 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
$vwm = Get-Var $main 'variableWidthMax'
$vwm['ValueExpression']['Expression'] = $vwm['ValueExpression']['Expression'].Replace("- 444", "- $(444 + $Widen)")
$vw = Get-Var $main 'variableWidth'
$vw['ValueExpression']['Expression'] = $vw['ValueExpression']['Expression'].Replace("isnull(`$prop('benofficial2.Relative.Width'), 430)", "isnull(`$prop('benofficial2.Relative.Width'), 430) + $Widen")
if ($vw['ValueExpression']['Expression'] -notmatch "\+ $Widen") { throw 'variableWidth patch failed' }
Update-RatingOffset (Get-Var $main 'RatingOffset')
$ho = Get-Var $main 'headerOffset'
$ho['ValueExpression']['Expression'] = $ho['ValueExpression']['Expression'].Replace('return 23', "return $HeaderH")
Add-Var $main 'panelHeight' "const maxRows = isnull(`$prop('benofficial2.Relative.MaxRows'), 3)`r`nconst footer = isnull(`$prop('benofficial2.Relative.FooterVisible'), true)`r`nreturn `$prop('variable.headerOffset') + (2 * maxRows + 1) * $R + (footer ? $FooterH : 6)"
Update-Metadata $main (Join-Path $TargetDir "$rel.djson.metadata") $NewW ($HeaderH + 11 * $R + $FooterH)

# rows: new pitch
$maxRowsJs = "const maxRows = isnull(`$prop('benofficial2.Relative.MaxRows'), 3)`r`n"
foreach ($spec in @(@('Ahead Repeat', "(maxRows - 1) * $R", -$R), @('Player', "maxRows * $R", 0), @('Behind Repeat', "(maxRows + 1) * $R", $R))) {
  $lay = Get-Child $layer $spec[0]
  if ($spec[2] -ne 0) { $lay['RepeatTopOffset'] = [double]$spec[2] }
  $w = $lay['Childrens'][0]
  $w['Height'] = [double]$R; $w['Width'] = [double]$NewW
  Set-Js $w 'Top' ($maxRowsJs + "return `$prop('variable.headerOffset') + " + $spec[1])
}

$chrome = New-PanelChrome "return isnull(`$prop('benofficial2.Relative.BackgroundOpacity'), 88)" '[variable.headerWidth]' '[variable.panelHeight]'
# timing column: iRacing draws it fully opaque (same gradient), so it reads lighter when the panel is translucent
$gapLeft = "401 + [variable.variableWidth] + [variable.RatingOffset] + [variable.LastLapTimeOffset] + [variable.TireCompoundOffset] + [variable.StintLapOffset] + $Shift + $ColExtra + 4"
$gapCol = New-OpaqueRegion 'Gap Column' $gapLeft "[variable.headerWidth] - 1 - ($gapLeft)" "`$prop('variable.headerOffset')" "(`$prop('variable.headerOffset') + (2 * isnull(`$prop('benofficial2.Relative.MaxRows'), 3) + 1) * $R)"
Insert-Children $layer 0 (@($chrome) + @($gapCol))

$header['Childrens'] = @(New-Title 'RELATIVE')
$header['Height'] = [double]$HeaderH

# ---------------- weather in the header (benofficial2's Precipitation / Track Wetness / Wind widgets) ----------------
# right-aligned: [cloud] precip %  [drops] track wetness %  [arrow] wind; precip/wetness hide at 0% when the
# widget's 'Hide when zero' setting is on, the remaining items move right.
$srcRoot = Split-Path $SourceDir
$wx = @{
  Precip = Join-Path $srcRoot 'benofficial2 - iRacing Precipitation\benofficial2 - iRacing Precipitation.djson'
  Wet    = Join-Path $srcRoot 'benofficial2 - iRacing Track Wetness\benofficial2 - iRacing Track Wetness.djson'
  Wind   = Join-Path $srcRoot 'benofficial2 - iRacing Wind\benofficial2 - iRacing Wind.djson'
}
if (@($wx.Values | Where-Object { -not (Test-Path $_) }).Count -eq 0) {
  $ress = Join-Path $TargetDir "$rel.djson.ressources"
  Copy-DashImages $main $ress $wx.Precip @('Rain Cloud')
  Copy-DashImages $main $ress $wx.Wet    @('Rain Drops')
  Copy-DashImages $main $ress $wx.Wind   @('Wind-Arrow')
  $precipVal = "isnull(`$prop('GameRawData.Telemetry.Precipitation'), 0)"
  $wetVal    = "Math.max(0, (100 / 6) * (isnull(`$prop('GameRawData.Telemetry.TrackWetness'), 0) - 1))"
  $precipVis = "!(isnull(`$prop('benofficial2.Precipitation.HideWhenZero'), true) && $precipVal == 0)"
  $wetVis    = "!(isnull(`$prop('benofficial2.TrackWetness.HideWhenZero'), true) && $wetVal == 0)"
  $windW = 112; $pctW = 74; $right = "`$prop('variable.headerWidth') - 10"   # ~22px air between the items
  function New-WeatherItem([string]$name, [string]$srcPath, [string]$imgName, [string]$textJs, [double]$w, [string]$leftJs, [string]$visJs) {
    $srcDash = Read-Dash $srcPath
    $icon = Copy-Deep (Find-Item @{ Childrens = $srcDash['Screens'][0]['Items'] } $imgName)
    $icon['Left'] = 0.0; $icon['Top'] = 4.0; $icon['Width'] = 16.0; $icon['Height'] = 16.0
    $txt = New-Text "$name Value" 21 0 ($w - 21) $R '' $TextWhite 13.0 0
    Set-Js $txt 'Text' $textJs
    $g = New-Group "Weather $name" 0 4 $w $R @($icon, $txt)
    Set-Js $g 'Left' $leftJs
    if ($visJs) { Set-Js $g 'Visible' "return $visJs" }
    $g
  }
  $windItem = New-WeatherItem 'Wind' $wx.Wind 'Wind Arrow' "return ''" $windW "return $right - $windW" ''
  # the original wind text binding defines windDirectionFromRadians() in its PreExpression: copy the whole binding
  $origWind = Find-Item @{ Childrens = (Read-Dash $wx.Wind)['Screens'][0]['Items'] } 'Wind Text'
  (Get-Child $windItem 'Wind Value')['Bindings']['Text'] = Copy-Deep $origWind['Bindings']['Text']
  $header['Childrens'] = @($header['Childrens']) + @(
    (New-WeatherItem 'Precip' $wx.Precip 'Rain Cloud' "return ($precipVal * 100).toFixed(0) + '%'" $pctW "return $right - $windW - (($wetVis) ? $pctW : 0) - $pctW" $precipVis),
    (New-WeatherItem 'Wetness' $wx.Wet 'Rain Drops' "return ($wetVal).toFixed(0) + '%'" $pctW "return $right - $windW - $pctW" $wetVis),
    $windItem
  )
  "Weather added to header"
} else { "Weather widgets not found next to the source - header without weather" }

# footer: Inc, SOF, Track (former header infos)
$footer['Height'] = [double]($FooterH - $CellGap)
Set-Js $footer 'Top' ($maxRowsJs + "return `$prop('variable.headerOffset') + (2 * maxRows + 1) * $R + $CellGap")
$footer['Childrens'] = @(New-FooterCells @(
  @('Inc',   (Get-Expr (Find-Orig $origHeader 'Incidents') 'Text')),
  @('SOF',   (Get-Expr (Find-Orig $origHeader 'SOF') 'Text')),
  @('Track', (Get-Expr (Find-Orig $origHeader 'Track Temp') 'Text'))
) '[variable.headerWidth]')

Set-Fonts @{ Childrens = @($layer) }
Write-Dash $mainPath $main
"Relative main restyled (BaseSize $($main['BaseWidth'])x$($main['BaseHeight']))"

# ---------------- Relative.js: player name/gap in iRacing yellow, off-white text ----------------
$jsPath = Join-Path $TargetDir "JavascriptExtensions\Relative.js"
$js = [IO.File]::ReadAllText($jsPath)
$js = $js.Replace("const highlighted = '#EBAE00'", "const highlighted = '#FFCC00'")
$js = $js.Replace("const white = 'White'", "const white = '#F2F2F3'")
$nl = if ($js.Contains("`r`n")) { "`r`n" } else { "`n" }   # keep the file's line endings (repo: LF, installer: CRLF)
$js = [regex]::Replace($js, "if \(index == 0\)\s*\{\s*const highlight = isnull\(\`$prop\('benofficial2\.Relative\.HighlightPlayerRow'\), false\)\s*if \(highlight\)\s*return white\s*", "if (index == 0)$nl    {$nl        ")
[IO.File]::WriteAllText($jsPath, $js, $utf8)
"Relative.js patched: " + ($js -match "const highlighted = '#FFCC00'")
