<#
.SYNOPSIS
  Restyles benofficial2's "iRacing Relative" overlay to look like the native iRacing (2025 UI) Relative box.

.DESCRIPTION
  Reads the ORIGINAL (unmodified) overlay from -SourceDir and writes the restyled overlay to -TargetDir.
  -SourceDir and -TargetDir may be the same folder, as long as it still contains the original files
  (the script refuses to run twice on already-styled files).

.EXAMPLE
  # In the repo, after pulling upstream changes:
  git checkout upstream/master -- "Overlays/benofficial2 - iRacing Relative"
  .\tools\iracing-style\Set-IracingStyleRelative.ps1 -SourceDir "Overlays\benofficial2 - iRacing Relative" -TargetDir "Overlays\benofficial2 - iRacing Relative"
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
$NewW      = $OrigW + $Shift + $GapExtra

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

Set-PlayerHighlight $hl "if (!($isPlayer))`r`n`treturn false`r`nreturn getRelativeRowVisible($idx)" '[variable.headerWidth] - 2'

# make room for position cell + class timeline: shift everything right of the position
foreach ($c in @($vis['Childrens'])) {
  $hasLeftBinding = $c['Bindings'] -and $c['Bindings'].ContainsKey('Left')
  if ([double]$c['Left'] -ge 20 -or $hasLeftBinding) { Add-ToLeft $c $Shift }
}
foreach ($n in 'DriverName', 'GapToPlayer', 'Position In Class') { (Get-Child $vis $n)['FontSize'] = $NameSize }

# timing value in the lighter column: starts 4px right of the pit/lap column, right-aligned, fixed-pitch digits
$gapTxt = Get-Child $vis 'GapToPlayer'
Add-ToLeft $gapTxt 4
$gapTxt['HorizontalAlignment'] = 2
$gpad = New-Dict; $gpad['PaddingRight'] = 6; $gapTxt['TextPadding'] = $gpad
$gapTxt['UseMonospacedText'] = $true; $gapTxt['CharWidth'] = 9.0; $gapTxt['SpecialCharsWidth'] = 7.0
Set-Nc $gapTxt 'Width' ("[variable.headerWidth] - 1 - (" + (Get-Expr $gapTxt 'Left') + ")")

$pos = Get-Child $vis 'Position In Class'
$pos['Left'] = [double]$PosLeft; $pos['Width'] = [double]$PosW
Set-Js $pos 'TextColor' "return ($isPlayer) ? '$OnYellow' : getRelativeTextColor($idx);"

$timeline = New-ClassTimeline $classColor "getRelativeProp($idx, 'CarClassColor') == getRelativeProp(0, 'CarClassColor')"
Insert-Children $vis 0 (@($timeline | Where-Object { $_['Name'] -like 'Class Glow*' }) + @(New-PosCell $isPlayer) + @($timeline | Where-Object { $_['Name'] -notlike 'Class Glow*' }))

$num = Get-Child $vis 'Number'
$numRight = [double]$num['Left'] + [double]$num['Width'] - 2
$hash = Set-NumberStyle $num "getRelativeProp($idx, 'Number')" $isPlayer $classColor "$numRight"
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
$vwm['ValueExpression']['Expression'] = $vwm['ValueExpression']['Expression'].Replace("- 444", "- $(444 + $Shift + $GapExtra)")
$vw = Get-Var $main 'variableWidth'
$vw['ValueExpression']['Expression'] = $vw['ValueExpression']['Expression'].Replace("isnull(`$prop('benofficial2.Relative.Width'), 430)", "isnull(`$prop('benofficial2.Relative.Width'), 430) + $($Shift + $GapExtra)")
if ($vw['ValueExpression']['Expression'] -notmatch "\+ $($Shift + $GapExtra)") { throw 'variableWidth patch failed' }
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
# lighter strip behind the timing column, spanning all rows up to the panel edge
$gapLeft = "401 + [variable.variableWidth] + [variable.RatingOffset] + [variable.LastLapTimeOffset] + [variable.TireCompoundOffset] + [variable.StintLapOffset] + $Shift + 4"
$gapCol = New-Rect 'Gap Column' 400 $HeaderH 44 220 '#FFFFFFFF' 5
Set-Nc $gapCol 'Left' $gapLeft
Set-Nc $gapCol 'Width' "[variable.headerWidth] - 1 - ($gapLeft)"
Set-Nc $gapCol 'Top' '[variable.headerOffset]'
Set-Js $gapCol 'Height' "return (2 * isnull(`$prop('benofficial2.Relative.MaxRows'), 3) + 1) * $R"
Insert-Children $layer 0 (@($chrome) + @($gapCol))

$header['Childrens'] = @(New-Title 'RELATIVE')
$header['Height'] = [double]$HeaderH

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
