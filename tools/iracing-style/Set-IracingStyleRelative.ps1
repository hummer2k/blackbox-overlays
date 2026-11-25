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
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 100MB; $ser.RecursionLimit = 1000
$utf8 = New-Object System.Text.UTF8Encoding($false)

$SourceDir = (Resolve-Path $SourceDir).Path
if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory $TargetDir | Out-Null }
$TargetDir = (Resolve-Path $TargetDir).Path
$rel = 'benofficial2 - iRacing Relative'
$fontDir = Join-Path $PSScriptRoot 'fonts'

# --- iRacing palette (sampled from screenshots) ---
$Yellow    = '#FFFFCC00'
$TextWhite = '#FFF2F2F3'   # iRacing text is slightly off-white (sampled)
$OnYellow  = '#FF16161C'
$MarkerFill= '#FF1E1E24'
$Weight    = 'SemiBold'

# --- metrics: measured on the iRacing box (row pitch 28px) and scaled to R ---
$R         = 24          # row height (benofficial2 original: 20)
$Shift     = 21          # car number right edge moves from 60 to 81 (room for pos cell + timeline)
$HeaderH   = 32          # title area = 1.34 rows
$GapExtra  = 14          # extra width for the timing column so it doesn't touch the pit/lap column
$CellGap   = 4           # gap rows->footer, between footer cells, bottom padding
$FooterH   = $CellGap + $R + $CellGap   # one row of footer cells
$NameSize  = 14.0        # names / position / gap
$NumSize   = 12.0        # car number ~ 0.5 R
$NumChar   = 7.0         # monospaced digit width at $NumSize
$FootSize  = 14.0
$PosLeft   = 3; $PosW = 28
$LineX     = 36          # 2px timeline, centre at 37
$OrigW     = 500         # benofficial2 dashboard width

# ---------------- helpers ----------------
function New-Dict { New-Object 'System.Collections.Generic.Dictionary[string,object]' }
function New-JsBinding([string]$expr) {   # JS with benofficial2 extensions available
  $f = New-Dict; $f['JSExt'] = 1; $f['Interpreter'] = 1; $f['Expression'] = $expr
  $b = New-Dict; $b['Formula'] = $f; $b['Mode'] = 2; $b
}
function New-NcBinding([string]$expr) {   # NCalc formula
  $f = New-Dict; $f['Expression'] = $expr
  $b = New-Dict; $b['Formula'] = $f; $b['Mode'] = 2; $b
}
function New-Radius([int]$tl, [int]$tr, [int]$bl, [int]$br) {   # SimHub requires integers here
  $d = New-Dict
  if ($tl) { $d['RadiusTopLeft'] = $tl }; if ($tr) { $d['RadiusTopRight'] = $tr }
  if ($bl) { $d['RadiusBottomLeft'] = $bl }; if ($br) { $d['RadiusBottomRight'] = $br }
  $d
}
function New-Base([string]$type) {
  $r = New-Dict
  $r['$type'] = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.$type, SimHub.Plugins"
  $r
}
function Complete-Item($r, [string]$name, $left, $top, $w, $h) {
  $r['Height'] = [double]$h; $r['Left'] = [double]$left; $r['Top'] = [double]$top
  $r['Visible'] = $true; $r['BlinkPhasisInverted'] = $false; $r['Width'] = [double]$w
  $r['Name'] = $name; $r['RenderingSkip'] = 0; $r['MinimumRefreshIntervalMS'] = 0.0
  $r['Bindings'] = New-Dict
  $r
}
function New-Rect([string]$name, $left, $top, $w, $h, [string]$color, $opacity = 100.0, $border = $null) {
  $r = New-Base 'RectangleItem'
  $r['IsRectangleItem'] = $true
  $r['BackgroundColor'] = $color
  if ($border) { $r['BorderStyle'] = $border }
  $r['Opacity'] = [double]$opacity
  Complete-Item $r $name $left $top $w $h
}
function New-Text([string]$name, $left, $top, $w, $h, [string]$text, [string]$color, [double]$size = 13.0, [int]$halign = 0, [string]$weight = $Weight) {
  $r = New-Base 'TextItem'
  $r['IsTextItem'] = $true; $r['Font'] = $Font; $r['FontWeight'] = $weight; $r['FontSize'] = $size
  $r['Text'] = $text; $r['TextColor'] = $color; $r['HorizontalAlignment'] = $halign; $r['VerticalAlignment'] = 1
  $r['BackgroundColor'] = '#00FFFFFF'
  Complete-Item $r $name $left $top $w $h
}
function Get-Child($parent, [string]$name) { @($parent['Childrens']) | Where-Object { $_['Name'] -eq $name } | Select-Object -First 1 }
function Set-Js($item, [string]$prop, [string]$expr) { if ($null -eq $item['Bindings']) { $item['Bindings'] = New-Dict }; $item['Bindings'][$prop] = New-JsBinding $expr }
function Set-Nc($item, [string]$prop, [string]$expr) { if ($null -eq $item['Bindings']) { $item['Bindings'] = New-Dict }; $item['Bindings'][$prop] = New-NcBinding $expr }
function Insert-Children($parent, [int]$at, [object[]]$items) {
  $list = New-Object System.Collections.ArrayList
  $list.AddRange(@($parent['Childrens'])); $list.InsertRange($at, $items)
  $parent['Childrens'] = $list.ToArray()
}
function Set-Fonts($item) {
  if ($item['Font'] -eq 'Roboto') { $item['Font'] = $Font; if ($item['FontWeight'] -eq 'Bold') { $item['FontWeight'] = $Weight } }
  if ($item['IsTextItem'] -and $item['TextColor'] -eq '#FFFFFFFF') { $item['TextColor'] = $TextWhite }
  if ($item['Childrens']) { foreach ($c in $item['Childrens']) { Set-Fonts $c } }
}
function Add-ToLeft($item, [double]$dx) {
  $item['Left'] = [double]$item['Left'] + $dx
  if ($item['Bindings'] -and $item['Bindings'].ContainsKey('Left')) {
    $f = $item['Bindings']['Left']['Formula']
    if ($f['Interpreter'] -eq 1) { $f['Expression'] = "return (function(){`r`n" + $f['Expression'] + "`r`n})() + $dx" }
    else { $f['Expression'] = '(' + $f['Expression'] + ") + $dx" }
  }
}
# stretch a 20px-high row item to $R: full-height items grow, smaller ones are re-centred
function Set-RowHeight($item, [double]$old, [double]$new) {
  if ([double]$item['Height'] -eq $old -and $item['$type'] -notmatch 'ImageItem') { $item['Height'] = $new }
  else { $item['Top'] = [double]$item['Top'] + ($new - $old) / 2 }
  if ($item['Childrens']) { foreach ($c in $item['Childrens']) { if ([double]$c['Height'] -eq $old) { $c['Height'] = $new } else { $c['Top'] = [double]$c['Top'] + ($new - $old) / 2 } } }
}
function Copy-Deep($o) { $ser.DeserializeObject((ConvertTo-JsonText $o)) }
function ConvertTo-JsonText($o) {
  if ($null -eq $o) { return 'null' }
  if ($o -is [System.Management.Automation.PSObject]) { $o = $o.psobject.BaseObject }
  if ($o -is [string]) { return $ser.Serialize($o) }
  if ($o -is [bool]) { if ($o) { return 'true' } else { return 'false' } }
  if ($o -is [double] -or $o -is [single] -or $o -is [decimal]) {
    $s = ([double]$o).ToString('R', [Globalization.CultureInfo]::InvariantCulture)
    if ($s -notmatch '[\.Ee]') { $s += '.0' }; return $s
  }
  if ($o -is [int] -or $o -is [long] -or $o -is [int16] -or $o -is [byte]) { return $o.ToString([Globalization.CultureInfo]::InvariantCulture) }
  if ($o -is [System.Collections.IDictionary]) {
    $parts = foreach ($k in $o.Keys) { $ser.Serialize([string]$k) + ':' + (ConvertTo-JsonText $o[$k]) }
    return '{' + ($parts -join ',') + '}'
  }
  if ($o -is [System.Collections.IEnumerable]) {
    $parts = foreach ($e in $o) { ConvertTo-JsonText $e }
    return '[' + ($parts -join ',') + ']'
  }
  throw "Unsupported type $($o.GetType().FullName)"
}
function Read-Dash([string]$path) { $ser.DeserializeObject([IO.File]::ReadAllText($path)) }
function Write-Dash([string]$path, $obj) {
  $json = ConvertTo-JsonText $obj
  if ($json -match '"Radius\w+":\d+\.\d' -or $json -match '"Border(Top|Bottom|Left|Right)":\d+\.\d') { throw "float in int field: $path" }
  [IO.File]::WriteAllText($path, $json, $utf8)
}
function Get-Var($dash, [string]$name) { $dash['Variables']['DashboardVariables'] | Where-Object { $_['VariableName'] -eq $name } | Select-Object -First 1 }
function Find-Orig($root, [string]$name) {
  # groups and their inner text share names (e.g. 'SOF'), so only accept items with a Text binding
  foreach ($c in @($root['Childrens'])) {
    if ($c['Name'] -eq $name -and $c['Bindings'] -and $c['Bindings'].ContainsKey('Text')) { return $c }
    if ($c['Childrens']) { $r = Find-Orig $c $name; if ($r) { return $r } }
  }
}

$classColor = "isnull(getRelativeProp(`$prop('variable.relativeIdx'), 'CarClassColor'), '#FFFFFF')"
$NewW = $OrigW + $Shift + $GapExtra

# ---------------- 1) start from the original files ----------------
if ([IO.File]::ReadAllText((Join-Path $SourceDir "$rel.djson")).Contains('"Panel Shade 1"')) {
  throw "SourceDir already contains the iRacing style - point it at the original benofficial2 files (e.g. git checkout upstream/master -- <dir>)."
}
if ($SourceDir -ne $TargetDir) { Copy-Item (Join-Path $SourceDir '*') $TargetDir -Recurse -Force }
# ship Inter with the overlay; SimHub copies _SHFonts into its DashFonts folder when the dash is imported
if ($Font -eq 'Inter' -and (Test-Path $fontDir)) {
  $shf = Join-Path $TargetDir '_SHFonts'; if (-not (Test-Path $shf)) { New-Item -ItemType Directory $shf | Out-Null }
  Copy-Item (Join-Path $fontDir 'Inter-*.ttf') $shf -Force
}
"Source: $SourceDir"; "Target: $TargetDir"; "Font:   $Font"

# ---------------- 2) Relative Row ----------------
$rowPath = Join-Path $TargetDir "Relative Row.djson"
$row = Read-Dash $rowPath
$row['BaseHeight'] = $R; $row['BaseWidth'] = $NewW
(Get-Var $row 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
$items = $row['Screens'][0]['Items']
$bg  = $items | Where-Object { $_['Name'] -eq 'Background' }
$hl  = $items | Where-Object { $_['Name'] -eq 'Player Highlight' }
$vis = $items | Where-Object { $_['Name'] -eq 'Visible' }

# taller rows (iRacing proportions)
foreach ($c in @($vis['Childrens'])) { Set-RowHeight $c 20 $R }

# per-row backgrounds caused seams; the panel is now drawn once in the main dash
$bg['Visible'] = $false; $bg['Bindings'].Remove('Visible') | Out-Null

# player row: faint gold wash
$hl['BackgroundColor'] = $Yellow; $hl['Opacity'] = 9.0
$hl['Left'] = 1.0; $hl['Top'] = 1.0; $hl['Height'] = [double]($R - 2)
$hl['BorderStyle'] = New-Radius 4 4 4 4
Set-Js $hl 'Visible' "const index = `$prop('variable.relativeIdx')`r`nif (index != 0)`r`n`treturn false`r`nreturn getRelativeRowVisible(index)"
Set-Nc $hl 'Width' '[variable.headerWidth] - 2'

# make room for position cell + class timeline: shift everything right of the position
foreach ($c in @($vis['Childrens'])) {
  $hasLeftBinding = $c['Bindings'] -and $c['Bindings'].ContainsKey('Left')
  if ([double]$c['Left'] -ge 20 -or $hasLeftBinding) { Add-ToLeft $c $Shift }
}

# font sizes like iRacing
foreach ($n in 'DriverName', 'GapToPlayer', 'Position In Class') { (Get-Child $vis $n)['FontSize'] = $NameSize }

# gap value in the lighter timing column: column starts 4px right of the pit/lap column and runs to the panel edge
$gapTxt = Get-Child $vis 'GapToPlayer'
Add-ToLeft $gapTxt 4
$gapTxt['HorizontalAlignment'] = 2          # iRacing: right-aligned, wide fixed-pitch digits
$gpad = New-Dict; $gpad['PaddingRight'] = 6; $gapTxt['TextPadding'] = $gpad
$gapTxt['UseMonospacedText'] = $true; $gapTxt['CharWidth'] = 9.0; $gapTxt['SpecialCharsWidth'] = 7.0
Set-Nc $gapTxt 'Width' ("[variable.headerWidth] - 1 - (" + $gapTxt['Bindings']['Left']['Formula']['Expression'] + ")")

# position cell (rounded, slightly lighter; solid yellow for the player)
$pos = Get-Child $vis 'Position In Class'
$pos['Left'] = [double]$PosLeft; $pos['Width'] = [double]$PosW
Set-Js $pos 'TextColor' "const index = `$prop('variable.relativeIdx');`r`nreturn index == 0 ? '$OnYellow' : getRelativeTextColor(index);"
# iRacing: only the left corners are rounded, very subtle lift (+4% white)
$posCell = New-Rect 'Pos Cell' $PosLeft 0.5 $PosW ($R - 1) '#0BFFFFFF' 100 (New-Radius 4 0 4 0)   # 1px hairline between cells like iRacing
Set-Js $posCell 'BackgroundColor' "return `$prop('variable.relativeIdx') == 0 ? '$Yellow' : '#0BFFFFFF'"

# class colour glow fading to the right (stacked translucent strips = gradient)
$glow = foreach ($w in 44, 36, 28, 20, 12, 6) {
  # overlap neighbouring rows by half a pixel so no seams appear when the overlay is scaled
  $g = New-Rect "Class Glow $w" ($LineX + 2) -0.25 $w ($R + 0.5) '#FFFFFFFF' 7
  Set-Js $g 'BackgroundColor' "return $classColor"
  $g
}
# class timeline + marker (square = same class as the focused car, circle = other class)
$line = New-Rect 'Class Line' $LineX -1 2 ($R + 2) '#FFFFFFFF' 100
Set-Js $line 'BackgroundColor' "return $classColor"
$mk = 10
$markers = foreach ($m in @(@('Marker Same Class', 2, '=='), @('Marker Other Class', 5, '!='))) {
  $bs = New-Dict
  $bs['BorderColor'] = '#FFFFFFFF'; $bs['BorderTop'] = 2; $bs['BorderBottom'] = 2; $bs['BorderLeft'] = 2; $bs['BorderRight'] = 2
  $bs['RadiusTopLeft'] = $m[1]; $bs['RadiusTopRight'] = $m[1]; $bs['RadiusBottomLeft'] = $m[1]; $bs['RadiusBottomRight'] = $m[1]
  $bs['Bindings'] = New-Dict; $bs['Bindings']['BorderColor'] = New-JsBinding "return $classColor"
  $marker = New-Rect $m[0] ($LineX + 1 - $mk / 2) (($R - $mk) / 2) $mk $mk $MarkerFill 100 $bs
  Set-Js $marker 'Visible' "const index = `$prop('variable.relativeIdx')`r`nreturn getRelativeProp(index, 'CarClassColor') $($m[2]) getRelativeProp(0, 'CarClassColor')"
  $marker
}
Insert-Children $vis 0 (@($glow) + @($posCell, $line) + @($markers))

# car number: smaller, white digits (yellow for player), '#' in class colour, no coloured box
$num = Get-Child $vis 'Number'
$num['BackgroundColor'] = '#00FFFFFF'; $num['TextColor'] = $TextWhite; $num['HorizontalAlignment'] = 2; $num['FontSize'] = $NumSize
$pad = New-Dict; $pad['PaddingRight'] = 2; $num['TextPadding'] = $pad
$num['UseMonospacedText'] = $true; $num['CharWidth'] = $NumChar; $num['SpecialCharsWidth'] = 4.0
$num['Bindings'].Remove('BackgroundColor') | Out-Null
Set-Js $num 'Text' "return '' + isnull(getRelativeProp(`$prop('variable.relativeIdx'), 'Number'), '');"
Set-Js $num 'TextColor' "return `$prop('variable.relativeIdx') == 0 ? '$Yellow' : '$TextWhite';"
$numRight = [double]$num['Left'] + [double]$num['Width'] - 2
$hash = New-Text 'Number Hash' ($numRight - 16) 0 9 $R '#' '#FFFFFFFF' $NumSize 2
Set-Js $hash 'Left' "const n = ('' + isnull(getRelativeProp(`$prop('variable.relativeIdx'), 'Number'), '')).length;`r`nreturn $numRight - $NumChar * n - 9;"
Set-Js $hash 'TextColor' "return $classColor"
$numIdx = [array]::IndexOf(@($vis['Childrens']), $num)
Insert-Children $vis ($numIdx + 1) @($hash)

Set-Fonts @{ Childrens = $items }
Write-Dash $rowPath $row
"Relative Row restyled"

# ---------------- 3) Relative main ----------------
$mainPath = Join-Path $TargetDir "$rel.djson"
$main = Read-Dash $mainPath
$main['BaseWidth'] = $NewW
$layer = $main['Screens'][0]['Items'][0]
$header = Get-Child $layer 'Header'
$footer = Get-Child $layer 'Footer'
$origFooter = Copy-Deep $footer
$origHeader = Copy-Deep $header

# widths: dashboard grows by $Shift, the min content width grows by $Shift, and the user's
# width setting is honoured (+$Shift) so the name column keeps its original size
(Get-Var $main 'dashboardWidth')['ValueExpression']['Expression'] = "$NewW"
$vwm = Get-Var $main 'variableWidthMax'
$vwm['ValueExpression']['Expression'] = $vwm['ValueExpression']['Expression'].Replace("- 444", "- $(444 + $Shift + $GapExtra)")
$vw = Get-Var $main 'variableWidth'
$vw['ValueExpression']['Expression'] = $vw['ValueExpression']['Expression'].Replace("isnull(`$prop('benofficial2.Relative.Width'), 430)", "isnull(`$prop('benofficial2.Relative.Width'), 430) + $($Shift + $GapExtra)")
if ($vw['ValueExpression']['Expression'] -notmatch "\+ $($Shift + $GapExtra)") { throw 'variableWidth patch failed' }
$ho = Get-Var $main 'headerOffset'
$ho['ValueExpression']['Expression'] = $ho['ValueExpression']['Expression'].Replace('return 23', "return $HeaderH")
$ph = New-Dict
$ph['VariableName'] = 'panelHeight'; $ph['EvaluateOnlyOnce'] = $false; $ph['OverrideWithParentDashboardVariableWhenAvailable'] = $false
$phx = New-Dict; $phx['JSExt'] = 1; $phx['Interpreter'] = 1
$phx['Expression'] = "const maxRows = isnull(`$prop('benofficial2.Relative.MaxRows'), 3)`r`nconst footer = isnull(`$prop('benofficial2.Relative.FooterVisible'), true)`r`nreturn `$prop('variable.headerOffset') + (2 * maxRows + 1) * $R + (footer ? $FooterH : 6)"
$ph['ValueExpression'] = $phx; $ph['EvaluateBeforeScreenRoles'] = $false
$vars = New-Object System.Collections.ArrayList; $vars.AddRange(@($main['Variables']['DashboardVariables'])); [void]$vars.Add($ph)
$main['Variables']['DashboardVariables'] = $vars.ToArray()
$main['BaseHeight'] = $HeaderH + 11 * $R + $FooterH
# keep the dashboard metadata (embedded and/or separate .metadata file) in sync with the new base size
if ($main.ContainsKey('Metadata') -and $main['Metadata']) { $main['Metadata']['Width'] = [double]$NewW; $main['Metadata']['Height'] = [double]$main['BaseHeight'] }
$metaPath = Join-Path $TargetDir "$rel.djson.metadata"
if (Test-Path $metaPath) {
  $meta = [IO.File]::ReadAllText($metaPath)
  $meta = [regex]::Replace($meta, '("Width":\s*)[0-9.]+', "`${1}$NewW.0")
  $meta = [regex]::Replace($meta, '("Height":\s*)[0-9.]+', "`${1}$($main['BaseHeight']).0")
  [IO.File]::WriteAllText($metaPath, $meta, $utf8)
}

# rows: new pitch
$maxRowsJs = "const maxRows = isnull(`$prop('benofficial2.Relative.MaxRows'), 3)`r`n"
foreach ($spec in @(@('Ahead Repeat', "(maxRows - 1) * $R", -$R), @('Player', "maxRows * $R", 0), @('Behind Repeat', "(maxRows + 1) * $R", $R))) {
  $lay = Get-Child $layer $spec[0]
  if ($spec[2] -ne 0) { $lay['RepeatTopOffset'] = [double]$spec[2] }
  $w = $lay['Childrens'][0]
  $w['Height'] = [double]$R; $w['Width'] = [double]$NewW
  Set-Js $w 'Top' ($maxRowsJs + "return `$prop('variable.headerOffset') + " + $spec[1])
}

# one continuous panel (no seams), darkening towards the bottom like iRacing
# 1px border in the lighter (top) panel tone, like the iRacing box
$pbs = New-Radius 8 8 8 8
$pbs['BorderColor'] = '#FF2C2C33'; $pbs['BorderTop'] = 1; $pbs['BorderBottom'] = 1; $pbs['BorderLeft'] = 1; $pbs['BorderRight'] = 1
$panel = New-Rect 'Panel' 0 0 444 300 '#FF26262E' 88 $pbs
Set-Js $panel 'BackgroundColor' "return `$prop('benofficial2.BackgroundColor')"
Set-Js $panel 'Opacity' "return isnull(`$prop('benofficial2.Relative.BackgroundOpacity'), 88)"
Set-Nc $panel 'Width' '[variable.headerWidth]'
Set-Nc $panel 'Height' '[variable.panelHeight]'
# shade bands: progressively stronger towards the bottom, slightly blue (iRacing: #222228 top -> #0F0F17 bottom);
# inset by 1px so the lighter border stays visible all around
$shadeOpacity = 2, 3, 6, 8, 9, 11, 12, 14
$bands = foreach ($k in 1..8) {
  $b = New-Rect "Panel Shade $k" 1 0 442 100 '#FF00000C' $shadeOpacity[$k - 1] (New-Radius 0 0 7 7)
  Set-Nc $b 'Width' '[variable.headerWidth] - 2'
  Set-Nc $b 'Top' "[variable.panelHeight] * $k / 9"
  Set-Nc $b 'Height' "[variable.panelHeight] * (9 - $k) / 9 - 1"
  $b
}
# lighter strip behind the gap column, spanning all rows up to the panel edge
$gapLeft = "401 + [variable.variableWidth] + [variable.RatingOffset] + [variable.LastLapTimeOffset] + [variable.TireCompoundOffset] + [variable.StintLapOffset] + $Shift + 4"
$gapCol = New-Rect 'Gap Column' 400 $HeaderH 44 220 '#FFFFFFFF' 5
Set-Nc $gapCol 'Left' $gapLeft
Set-Nc $gapCol 'Width' "[variable.headerWidth] - 1 - ($gapLeft)"
Set-Nc $gapCol 'Top' '[variable.headerOffset]'
Set-Js $gapCol 'Height' "return (2 * isnull(`$prop('benofficial2.Relative.MaxRows'), 3) + 1) * $R"
Insert-Children $layer 0 (@($panel) + @($bands) + @($gapCol))

# header: just the yellow title, like iRacing
$title = New-Text 'Title' 9 4 200 $R 'RELATIVE' $Yellow 15.0 0 'Bold'
$header['Childrens'] = @($title)
$header['Height'] = [double]$HeaderH

# footer: 2 x 4 iRacing-style cells (yellow label left, white value right), incl. the former header infos
$footer['Height'] = [double]($FooterH - $CellGap)
Set-Js $footer 'Top' ($maxRowsJs + "return `$prop('variable.headerOffset') + (2 * maxRows + 1) * $R + $CellGap")
$ex = @{
  Session = (Find-Orig $origFooter 'Session Type')['Bindings']['Text']['Formula']['Expression']
  Lap     = (Find-Orig $origFooter 'Current Lap')['Bindings']['Text']['Formula']['Expression'].Replace("return 'Lap ' + currentLap", "return '' + currentLap")
  Left    = (Find-Orig $origFooter 'Time Left')['Bindings']['Text']['Formula']['Expression']
  Drivers = "return isnull(`$prop('benofficial2.Standings.TotalDriverCount'), 0)"
  Inc     = (Find-Orig $origHeader 'Incidents')['Bindings']['Text']['Formula']['Expression']
  SoF     = (Find-Orig $origHeader 'SOF')['Bindings']['Text']['Formula']['Expression']
  Track   = (Find-Orig $origHeader 'Track Temp')['Bindings']['Text']['Formula']['Expression']
  Clock   = "const type = `$prop('benofficial2.Relative.ClockType')`r`nif (type == 1 || type == 'TrackTime')`r`n`treturn `$prop('variable.trackTime')`r`nconst d = new Date(`$prop('DataCorePlugin.CurrentDateTime'))`r`nconst h = d.getHours(), m = String(d.getMinutes()).padStart(2, '0')`r`nif (isnull(`$prop('benofficial2.ClockFormat24h'), true))`r`n`treturn String(h).padStart(2, '0') + ':' + m`r`nreturn (h % 12 || 12) + ':' + m + (h >= 12 ? ' PM' : ' AM')"
}
$cells = @(
  @('Inc','Inc', 0, 0), @('SoF','SOF', 1, 0), @('Track','Track', 2, 0)
)
$cols = 3
$cw = "(([variable.headerWidth] - $(2 * $PosLeft) - $(($cols - 1) * $CellGap)) / $cols)"
$footerItems = foreach ($c in $cells) {
  # NB: PowerShell variables are case-insensitive - never name anything $r here (it would overwrite $R)
  $key, $label, $col, $cellRow = $c
  $top = ($R + $CellGap) * $cellRow
  $leftExpr = "$PosLeft + $col * ($cw + $CellGap)"
  $cellBg = New-Rect "$label Cell" 0 $top 100 $R '#FFFFFFFF' 4 (New-Radius 4 4 4 4)
  Set-Nc $cellBg 'Left' $leftExpr; Set-Nc $cellBg 'Width' $cw
  $lab = New-Text "$label Label" 0 $top 90 $R $label $Yellow $FootSize 0
  Set-Nc $lab 'Left' "$leftExpr + 12"; Set-Nc $lab 'Width' "$cw - 20"
  if ($key -eq 'Session') {
    # "Session" + "Practice" does not fit one cell: show the session type itself as the yellow label
    Set-Js $lab 'Text' $ex[$key]
    $cellBg; $lab
    continue
  }
  $val = New-Text "$label Value" 0 $top 90 $R '' $TextWhite $FootSize 2
  Set-Nc $val 'Left' "$leftExpr + 12"; Set-Nc $val 'Width' "$cw - 20"
  Set-Js $val 'Text' $ex[$key]
  $cellBg; $lab; $val
}
$footer['Childrens'] = @($footerItems)

Set-Fonts @{ Childrens = @($layer) }
Write-Dash $mainPath $main
"Relative main restyled (BaseSize $($main['BaseWidth'])x$($main['BaseHeight']))"

# ---------------- 4) Relative.js: player name/gap in iRacing yellow ----------------
$jsPath = Join-Path $TargetDir "JavascriptExtensions\Relative.js"
$js = [IO.File]::ReadAllText($jsPath)
$js = $js.Replace("const highlighted = '#EBAE00'", "const highlighted = '#FFCC00'")
$js = $js.Replace("const white = 'White'", "const white = '#F2F2F3'")
$nl = if ($js.Contains("`r`n")) { "`r`n" } else { "`n" }   # keep the file's line endings (repo: LF, installer: CRLF)
$js = [regex]::Replace($js, "if \(index == 0\)\s*\{\s*const highlight = isnull\(\`$prop\('benofficial2\.Relative\.HighlightPlayerRow'\), false\)\s*if \(highlight\)\s*return white\s*", "if (index == 0)$nl    {$nl        ")
[IO.File]::WriteAllText($jsPath, $js, $utf8)
"Relative.js patched: " + ($js -match "const highlighted = '#FFCC00'")
