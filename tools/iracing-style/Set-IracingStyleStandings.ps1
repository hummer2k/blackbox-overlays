<#
.SYNOPSIS
  Restyles benofficial2's "iRacing Multi-Class Standings" overlay in the native iRacing (2025 UI) look,
  keeping the per-class grouping.

.DESCRIPTION
  Reads the ORIGINAL (unmodified) overlay from -SourceDir and writes the restyled overlay to -TargetDir.
  Same look as the Relative: one continuous panel with border and shade, yellow STANDINGS title,
  class timeline + markers + glow, left-rounded position cells, '#' in class colour, Inter font.
  The former header (session type, lap, time left) moves into footer cells (Lap, Left).

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
$name = 'benofficial2 - iRacing Multi-Class Standings'

$Shift    = 20           # room for position cell + class timeline before the car number
$OrigW    = 690          # benofficial2 dashboard width
$OrigRowW = 641          # benofficial2 minimum row width
$TimeColW = 72           # best/last columns: 65 -> 72 so Roboto Mono times fit inside the purple/green pills
$TimeExtra = $TimeColW - 65
# column gaps like the Relative: extra space per column in multiples of $ColGap, cumulative from left to right
$ColSteps = [ordered]@{ 'Country Flag' = 1; 'Driver Name' = 2; 'OutLap' = 2; 'Joker' = 2; 'Car Logo' = 2; 'Rating' = 3;
                        'Gap to Leader' = 4; 'Interval' = 5; 'Best Lap Time' = 6; 'Last Lap Time' = 7; 'Delta Lap Time' = 8;
                        'Tire Compound' = 9; 'Pit Status' = 10; 'Pit Time' = 11 }
$HdrSteps = [ordered]@{ 'Gap' = 4; 'Interval' = 5; 'Best' = 6; 'Last' = 7; 'Delta' = 8; 'Pit' = 10; 'Pit Time' = 11 }
$ColExtra = 11 * $ColGap
$PcExtra  = 6            # position change column 25 -> 31 so two digits fit in the pill
$DeltaExtra = 8          # delta pill 34 -> 42: some padding around '+0.1'
$Widen    = $Shift + 2 * $TimeExtra + $DeltaExtra + $RatingExtra + $ColExtra   # total extra row width (incl. larger rating badge)
$NewW     = $OrigW + $Widen
$ClassGap = 4            # space above each class block
$ClassHdr = 24           # class header height (badge, SOF, drivers, column titles)

$ci         = "`$prop('variable.ClassIdx')"
$ri         = "(repeatindex() - 1)"
$isPlayer   = "isnull(getStandingsProp($ci, $ri, 'IsHighlighted'), false)"
$classColor = "isnull(getStandingsProp($ci, $ri, 'CarClassColor'), '#FFFFFF')"

# JS: vertical offset of class block $limitExpr (sum of all previous visible class blocks)
function Get-BlockLoopJs([string]$limitExpr) {
@"
const titleVisible = isnull(`$prop('benofficial2.Standings.HeaderVisible'), true);
const classHeaderVisible = isnull(`$prop('benofficial2.Standings.CarClassHeaderVisible'), true);
let offset = titleVisible ? $HeaderH : 6;
for (let i = 0; i < $limitExpr; i++)
{
	const visibleRowCount = isnull(getStandingsClassProp(i, 'VisibleRowCount'), 0);
	if (visibleRowCount > 0)
	{
		offset += $ClassGap + visibleRowCount * $R;
		if (isDividerVisible(i)) offset += 3;
		if (classHeaderVisible) offset += $ClassHdr;
	}
}
"@ -replace "`r`n", "`n"   # same output whether git checked this script out with LF or CRLF
}
# player name / timing colours: iRacing shows the player's row in yellow, everything else off-white
function Set-StandingsTextColor($item) {
  if (-not ($item['Bindings'] -and $item['Bindings'].ContainsKey('TextColor'))) { return }
  $f = $item['Bindings']['TextColor']['Formula']
  $e = [regex]::Replace($f['Expression'], "if \(isnull\(\`$prop\('benofficial2\.Standings\.HighlightPlayerRow'\), true\)\)\s*return 'White'\s*", '')
  $f['Expression'] = $e.Replace("'White'", "'#F2F2F3'")
}

Initialize-Target $SourceDir $TargetDir "$name.djson"

# ---------------- Class Standings (one widget per class) ----------------
$csPath = Join-Path $TargetDir 'Class Standings.djson'
$cs = Read-Dash $csPath
$cs['BaseWidth'] = [int]($cs['BaseWidth'] + $Widen)
(Get-Var $cs 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
(Get-Var $cs 'PlayerNameTextColor')['ValueExpression']['Expression'] = "'#FFCC00'"
$v = Get-Var $cs 'variableWidth'
$v['ValueExpression']['Expression'] = $v['ValueExpression']['Expression'].Replace("- $OrigRowW", "- $($OrigRowW + $Widen)").Replace("isnull(`$prop('benofficial2.Standings.Width'), 730)", "isnull(`$prop('benofficial2.Standings.Width'), 730) + $Widen")
if ($v['ValueExpression']['Expression'] -notmatch "\+ $Widen") { throw 'variableWidth patch failed' }
$hw = Get-Var $cs 'headerWidth'
$hw['ValueExpression']['Expression'] = $hw['ValueExpression']['Expression'].Replace("$OrigRowW +", "$($OrigRowW + $Widen) +")
Update-RatingOffset (Get-Var $cs 'RatingOffset') ($RatingExtra + $ColGap)
# hidden columns must free their new width and their column gap
$hiddenW = [ordered]@{ 'CountryOffset' = 20; 'GapOffset' = 37; 'IntervalOffset' = 37; 'BestOffset' = 67; 'LastOffset' = 67; 'DeltaOffset' = 31; 'PitTimeOffset' = 45 }
foreach ($vn in $hiddenW.Keys) {
  $o = Get-Var $cs $vn; $old = $hiddenW[$vn]
  $new = $old + $ColGap + $(if ($vn -in 'BestOffset', 'LastOffset') { $TimeExtra } elseif ($vn -eq 'DeltaOffset') { $DeltaExtra } else { 0 })
  $e = $o['ValueExpression']['Expression']
  if ($e -notmatch ",0,-$old\)$") { throw "$vn patch failed: $e" }
  $o['ValueExpression']['Expression'] = $e -replace ",0,-$old\)$", ",0,-$new)"
}
# class badge width: benofficial2 scales a measured text size for Roboto (x0.54); Inter is ~15% wider
$cn = Get-Var $cs 'ClassNameWidth'
$cn['ValueExpression']['Expression'] = $cn['ValueExpression']['Expression'].Replace('textSize * 0.54 + 4', 'textSize * 0.62 + 10')
if ($cn['ValueExpression']['Expression'] -notmatch '0\.62') { throw 'ClassNameWidth patch failed' }

$root   = $cs['Screens'][0]['Items'][0]
$rowRep = Get-Child $root 'Row Repeat'
$row    = $rowRep['Childrens'][0]
$hdr    = Get-Child $root 'Header'

# rows: new pitch and start below the taller class header
$rowRep['RepeatTopOffset'] = [double]$R
$rt = $row['Bindings']['Top']['Formula']
$rt['Expression'] = $rt['Expression'].Replace('let top = 7.5;', "let top = $ClassGap;").Replace('const headerHeight = 18;', "const headerHeight = $ClassHdr;")
if ($rt['Expression'] -notmatch "let top = $ClassGap;") { throw 'row Top patch failed' }
$row['Height'] = [double]$R
foreach ($c in @($row['Childrens'])) { Set-RowHeight $c 20 $R }

$bg = Get-Child $row 'Background'
$bg['Visible'] = $false
$hl = Get-Child $row 'Player Highlight'
Set-PlayerHighlight $hl (Get-Expr $hl 'Visible') '[variable.headerWidth] - 2'

foreach ($c in @($row['Childrens'])) {
  $hasLeftBinding = $c['Bindings'] -and $c['Bindings'].ContainsKey('Left')
  if ($c['Name'] -ne 'Position In Class' -and ([double]$c['Left'] -ge 20 -or $hasLeftBinding)) { Add-ToLeft $c $Shift }
  Set-StandingsTextColor $c
}
(Get-Child $row 'Driver Name')['FontSize'] = $NameSize

$pos = Get-Child $row 'Position In Class'
$pos['Left'] = [double]$PosLeft; $pos['Width'] = [double]$PosW; $pos['FontSize'] = $NameSize; $pos['HorizontalAlignment'] = 1
Set-Js $pos 'TextColor' "return ($isPlayer) ? '$OnYellow' : '$TextWhite';"

# larger, outlined rating badge: everything right of it moves along
Set-RatingStyle (Get-Child $row 'Rating')
foreach ($n in 'Gap to Leader', 'Interval', 'Best Lap Time', 'Last Lap Time', 'Delta Lap Time', 'Tire Compound', 'Pit Status', 'Pit Time') { Add-ToLeft (Get-Child $row $n) $RatingExtra }
# wider best/last columns: everything right of them moves along
$colShift = @{ 'Last Lap Time' = $TimeExtra; 'Delta Lap Time' = 2 * $TimeExtra; 'Tire Compound' = 2 * $TimeExtra + $DeltaExtra; 'Pit Status' = 2 * $TimeExtra + $DeltaExtra; 'Pit Time' = 2 * $TimeExtra + $DeltaExtra }
(Get-Child $row 'Delta Lap Time')['Width'] = [double](Get-Child $row 'Delta Lap Time')['Width'] + $DeltaExtra
foreach ($n in $colShift.Keys) { Add-ToLeft (Get-Child $row $n) $colShift[$n] }
foreach ($n in 'Best Lap Time', 'Last Lap Time') { (Get-Child $row $n)['Width'] = [double]$TimeColW }
# column spacing as in the Relative (the name keeps its width; everything right of it moves along)
foreach ($n in $ColSteps.Keys) { Add-ToLeft (Get-Child $row $n) ($ColSteps[$n] * $ColGap) }
# benofficial2's logo sits 3px further left of the rating than in the Relative
foreach ($n in 'OutLap', 'Joker', 'Car Logo') { Add-ToLeft (Get-Child $row $n) 3 }

# best / last lap highlights (purple / green) as rounded pills instead of full-height blocks
foreach ($n in 'Best Lap Time', 'Last Lap Time', 'Delta Lap Time') { Set-Pill (Get-Child $row $n); Set-PillTextWhite (Get-Child $row $n) }
Set-PitPills $row
Set-IracingTyreIcons $row
# keep long names clear of the OUT badge (31px); the joker icon is already accounted for by benofficial2
Set-NameBadgeRoom (Get-Child $row 'Driver Name') "isnull(getStandingsProp($ci, $ri, 'OutLap'), false) ? 34 : 0"
# iRacing-like fixed-pitch timing digits
foreach ($n in 'Best Lap Time', 'Last Lap Time', 'Delta Lap Time', 'Gap to Leader', 'Interval', 'Pit Time') { Set-TimingMonospace (Get-Child $row $n) }

# class colour once per class widget; the ~25 timeline items per row read it via a cheap NCalc binding
Add-Var $cs 'classColor' "return isnull(getClassColor($ci), '#FFFFFF')"
# classes are sorted fastest first, so the class index is iRacing's class rank (marker shape)
Add-Var $cs 'classShape' "return ($ci) % 3"
$timeline = New-ClassTimeline '[variable.classColor]' '[variable.classShape]'
Insert-Children $row 2 (@($timeline | Where-Object { $_['Name'] -like 'Class Glow*' }) + @(New-PosCell $isPlayer) + @($timeline | Where-Object { $_['Name'] -notlike 'Class Glow*' }))

$num = Get-Child $row 'Number'
$hash = Set-NumberStyle $num "getStandingsProp($ci, $ri, 'Number')" $isPlayer '[variable.classColor]' "(49 + $Shift - 25) + 34 - 2"
Insert-Children $row ([array]::IndexOf(@($row['Childrens']), $num) + 1) @($hash)

# position change (race): green / red pill like the delta, white caret + number, placed right of
# the rating badge instead of on the class colour. benofficial2 reserves its 25px column in front of the car
# number via PositionChangeOffset (0 visible / -25 hidden): that column is now always gone (-25 fixed for
# everything up to the rating), and PositionChangeOffset instead makes room for the pill after the rating, so the
# timing columns, the row width and the column titles all follow it (the name column gives the space back).
$pcGroup = Get-Child $row 'Position Change'
$pcW = [double]$pcGroup['Width'] + $PcExtra
$pcGroup['Width'] = $pcW
$pcoNc = '[variable.PositionChangeOffset]'; $pcoJs = "`$prop('variable.PositionChangeOffset')"
foreach ($n in 'Number', 'Country Flag', 'Driver Name', 'OutLap', 'Joker', 'Car Logo', 'Rating') {
  foreach ($b in (Get-Child $row $n)['Bindings'].Values) {
    $b['Formula']['Expression'] = $b['Formula']['Expression'].Replace($pcoNc, '(-25)').Replace($pcoJs, '(-25)')
  }
}
# same spot the first timing column would take without the pill
Set-Nc $pcGroup 'Left' ((Get-Expr (Get-Child $row 'Gap to Leader') 'Left').Replace($pcoNc, '(-25)'))
$pcJs = "const change = isnull(getStandingsProp($ci, $ri, 'PositionChange'), 0);"
$pill = Get-Child $pcGroup 'RectangleItem'
$pill['Left'] = 0.0; $pill['Top'] = 2.0; $pill['Width'] = $pcW; $pill['Height'] = [double]($R - 4)
# benofficial2's fill colours are the delta's (green #7352E052 / red #73FF6345): keep them, round like the delta
$pill['BorderStyle'] = New-Radius 4 4 4 4
$pcText = Get-Child $pcGroup 'Position Change'
$pcText['Bindings'].Remove('Left') | Out-Null
$pcText['Left'] = 11.0; $pcText['Width'] = $pcW - 13; $pcText['Top'] = 0.0; $pcText['Height'] = [double]$R
$pcText['HorizontalAlignment'] = 1; $pcText['TextColor'] = $TextWhite
Set-TimingMonospace $pcText
$caret = Get-Child $pcGroup 'Caret'
foreach ($b in 'Left', 'Top') { $caret['Bindings'].Remove($b) | Out-Null }
$caret['Left'] = 5.0; $caret['Width'] = 7.0; $caret['Height'] = 7.0; $caret['Top'] = ($R - 7) / 2
$pco = Get-Var $cs 'PositionChangeOffset'
$e = $pco['ValueExpression']['Expression']
if ($e -notmatch ',0,-25\)$') { throw "PositionChangeOffset patch failed: $e" }
$pco['ValueExpression']['Expression'] = $e -replace ',0,-25\)$', ",$($pcW + $ColGap - 25),-25)"

# class header: no own background, rounded class badge, dim column titles, thin class-colour underline
$hdr['Top'] = [double]$ClassGap; $hdr['Height'] = [double]$ClassHdr
(Get-Child $hdr 'Background')['Visible'] = $false
$line = Get-Child $hdr 'Line'
$line['Top'] = 0.0; $line['Height'] = [double]$ClassHdr; $line['BorderStyle']['BorderBottom'] = 2
$badge = Get-Child $hdr 'Car Class Background'
$badge['Top'] = 3.0; $badge['Height'] = 18.0; $badge['BorderStyle'] = New-Radius 4 4 4 4
foreach ($c in @($hdr['Childrens'])) {
  if ($c['Name'] -in 'Background', 'Line', 'Car Class Background') { continue }
  $c['Top'] = [double]$c['Top'] + 5                     # re-centre in the 24px header
  if ($c['Bindings'] -and $c['Bindings'].ContainsKey('Left') -and $c['Name'] -notin 'SOF', 'Driver Count') { Add-ToLeft $c $Shift }
  if ($c['$type'] -match 'TextItem' -and $c['Name'] -ne 'Car Class') { $c['TextColor'] = $TextDim }
}
(Get-Child $hdr 'Car Class')['Top'] = 2.0
# column titles follow the larger rating badge and the wider best/last columns
foreach ($n in 'Gap', 'Interval', 'Best', 'Last', 'Delta', 'Pit', 'Pit Time') { Add-ToLeft (Get-Child $hdr $n) $RatingExtra }
$hdrShift = @{ 'Last' = $TimeExtra; 'Delta' = 2 * $TimeExtra; 'Pit' = 2 * $TimeExtra + $DeltaExtra; 'Pit Time' = 2 * $TimeExtra + $DeltaExtra }
(Get-Child $hdr 'Delta')['Width'] = [double](Get-Child $hdr 'Delta')['Width'] + $DeltaExtra
foreach ($n in $hdrShift.Keys) { Add-ToLeft (Get-Child $hdr $n) $hdrShift[$n] }
foreach ($n in 'Best', 'Last') { (Get-Child $hdr $n)['Width'] = [double]$TimeColW }
foreach ($n in $HdrSteps.Keys) { Add-ToLeft (Get-Child $hdr $n) ($HdrSteps[$n] * $ColGap) }
# "STINT" is right-aligned with 5px padding in 36px - too narrow for Inter: grow it to the left
$stint = Get-Child $hdr 'Pit'
Add-ToLeft $stint -10; $stint['Width'] = [double]$stint['Width'] + 10

Set-Fonts @{ Childrens = @($root) }
Write-Dash $csPath $cs
"Class Standings restyled"

# ---------------- main ----------------
$mainPath = Join-Path $TargetDir "$name.djson"
$main = Read-Dash $mainPath
$layer  = $main['Screens'][0]['Items'][0]
$repeat = Get-Child $layer 'Class Standings Repeat'
$header = Get-Child $layer 'Header'
$origHeader = Copy-Deep $header

# the panel needs the row width, which is computed inside the class widget: mirror those variables here
# (the widget's offset variables override from the parent, so both always agree)
(Get-Var $main 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
$csSrc = Read-Dash $csPath
$vars = New-Object System.Collections.ArrayList; $vars.AddRange(@($main['Variables']['DashboardVariables']))
foreach ($vn in 'PositionChangeOffset', 'GapOffset', 'IntervalOffset', 'BestOffset', 'LastOffset', 'RatingOffset', 'DeltaOffset', 'PitTimeOffset', 'variableWidth') {
  [void]$vars.Add((Copy-Deep (Get-Var $csSrc $vn)))
}
$rw = Copy-Deep (Get-Var $csSrc 'headerWidth'); $rw['VariableName'] = 'rowWidth'; [void]$vars.Add($rw)
$main['Variables']['DashboardVariables'] = $vars.ToArray()
Add-Var $main 'panelHeight' ((Get-BlockLoopJs "isnull(`$prop('benofficial2.Standings.VisibleClassCount'), 0)") + "return offset + $FooterH;")

# class blocks: new vertical layout
$w = $repeat['Childrens'][0]
$w['Width'] = [double]($w['Width'] + $Widen)
Set-Js $w 'Top' ((Get-BlockLoopJs 'repeatindex() - 1') + 'return offset;')

$chrome = New-PanelChrome "return isnull(`$prop('benofficial2.Standings.BackgroundOpacity'), 88)" '[variable.rowWidth]' '[variable.panelHeight]'
Insert-Children $layer 0 @($chrome)

$header['Childrens'] = @(New-Title 'STANDINGS')
$header['Height'] = [double]$HeaderH
Set-Nc $header 'Width' '[variable.rowWidth]'

$footer = New-Group 'Footer' 0 0 $NewW $R @(New-FooterCells @(
  @('Lap',  (Get-Expr (Find-Orig $origHeader 'CurrentLap') 'Text').Replace("return 'Lap ' + currentLap", "return '' + currentLap")),
  @('Left', (Get-Expr (Find-Orig $origHeader 'Time Left') 'Text'))
) '[variable.rowWidth]')
Set-Nc $footer 'Top' "[variable.panelHeight] - $($FooterH - $CellGap)"
Set-Nc $footer 'Width' '[variable.rowWidth]'
Insert-Children $layer (@($layer['Childrens']).Count) @($footer)

Update-Metadata $main (Join-Path $TargetDir "$name.djson.metadata") $NewW ([Math]::Round(695 * $R / 20) + $HeaderH - 20)
Set-Fonts @{ Childrens = @($layer) }
Write-Dash $mainPath $main
"Standings main restyled (BaseSize $($main['BaseWidth'])x$($main['BaseHeight']))"
