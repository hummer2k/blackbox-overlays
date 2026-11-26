# Shared building blocks for the iRacing-style overlay scripts. Dot-source it AFTER setting $Font:
#   . (Join-Path $PSScriptRoot 'IracingStyle.Common.ps1')
# NB: PowerShell variables are case-insensitive - never use $r for anything (it would overwrite $R).

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = 100MB; $ser.RecursionLimit = 1000
$utf8 = New-Object System.Text.UTF8Encoding($false)
$fontDir = Join-Path $PSScriptRoot 'fonts'

# --- iRacing palette (sampled from screenshots) ---
$Yellow    = '#FFFFCC00'
$TextWhite = '#FFF2F2F3'   # iRacing text is slightly off-white
$TextDim   = '#FF8E8E99'   # secondary labels (column titles)
$OnYellow  = '#FF16161C'
$MarkerFill= '#FF1E1E24'
$Weight    = 'SemiBold'

# --- metrics: measured on the iRacing boxes (row pitch 28px) and scaled to R ---
$R         = 24          # row height (benofficial2 original: 20)
$HeaderH   = 32          # title area = 1.34 rows
$CellGap   = 4           # gap above footer, between footer cells, bottom padding
$FooterH   = $CellGap + $R + $CellGap   # one row of footer cells
$NameSize  = 14.0        # names / position / timing
$NumSize   = 12.0        # car number ~ 0.5 R
$NumChar   = 7.0         # monospaced digit width at $NumSize
$FootSize  = 14.0
# iRacing sets timing in a separate monospace font ('1' with a foot, square ':' and '.'): Roboto Mono (SIL OFL).
# Advance width is 0.6 em, so 13px keeps "1:46.414" (8 x 7.8px) inside benofficial2's 65px columns.
$TimeFont   = 'Roboto Mono'
$TimeWeight = 'Bold'
$TimeSize   = 13.0
$PosLeft   = 3; $PosW = 28
$LineX     = 36          # 2px class timeline, centre at 37

# ---------------- JSON model helpers ----------------
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
  $o = New-Dict
  $o['$type'] = "SimHub.Plugins.OutputPlugins.GraphicalDash.Models.$type, SimHub.Plugins"
  $o
}
function Complete-Item($o, [string]$name, $left, $top, $w, $h) {
  $o['Height'] = [double]$h; $o['Left'] = [double]$left; $o['Top'] = [double]$top
  $o['Visible'] = $true; $o['BlinkPhasisInverted'] = $false; $o['Width'] = [double]$w
  $o['Name'] = $name; $o['RenderingSkip'] = 0; $o['MinimumRefreshIntervalMS'] = 0.0
  $o['Bindings'] = New-Dict
  $o
}
function New-Rect([string]$name, $left, $top, $w, $h, [string]$color, $opacity = 100.0, $border = $null) {
  $o = New-Base 'RectangleItem'
  $o['IsRectangleItem'] = $true
  $o['BackgroundColor'] = $color
  if ($border) { $o['BorderStyle'] = $border }
  $o['Opacity'] = [double]$opacity
  Complete-Item $o $name $left $top $w $h
}
function New-Text([string]$name, $left, $top, $w, $h, [string]$text, [string]$color, [double]$size = 13.0, [int]$halign = 0, [string]$weight = $Weight) {
  $o = New-Base 'TextItem'
  $o['IsTextItem'] = $true; $o['Font'] = $Font; $o['FontWeight'] = $weight; $o['FontSize'] = $size
  $o['Text'] = $text; $o['TextColor'] = $color; $o['HorizontalAlignment'] = $halign; $o['VerticalAlignment'] = 1
  $o['BackgroundColor'] = '#00FFFFFF'
  Complete-Item $o $name $left $top $w $h
}
function New-Group([string]$name, $left, $top, $w, $h, [object[]]$children) {
  $o = New-Base 'GroupItem'
  $o['ChildsPositioning'] = 0; $o['ChildsPositioningAlignment'] = 0; $o['GroupPadding'] = (New-Dict); $o['ChildsMargin'] = (New-Dict)
  $o['ChildAlignmentHorizontal'] = 0; $o['ChildAlignmentVertical'] = 0; $o['Childrens'] = @($children)
  $o['BackgroundColor'] = '#00FFFFFF'
  Complete-Item $o $name $left $top $w $h
}
function Get-Child($parent, [string]$name) { @($parent['Childrens']) | Where-Object { $_['Name'] -eq $name } | Select-Object -First 1 }
function Find-Item($root, [string]$name) {
  foreach ($c in @($root['Childrens'])) { if ($c['Name'] -eq $name) { return $c }; if ($c['Childrens']) { $f = Find-Item $c $name; if ($f) { return $f } } }
}
function Find-Orig($root, [string]$name) {
  # groups and their inner text share names (e.g. 'SOF'), so only accept items with a Text binding
  foreach ($c in @($root['Childrens'])) {
    if ($c['Name'] -eq $name -and $c['Bindings'] -and $c['Bindings'].ContainsKey('Text')) { return $c }
    if ($c['Childrens']) { $f = Find-Orig $c $name; if ($f) { return $f } }
  }
}
function Set-Js($item, [string]$prop, [string]$expr) { if ($null -eq $item['Bindings']) { $item['Bindings'] = New-Dict }; $item['Bindings'][$prop] = New-JsBinding $expr }
function Set-Nc($item, [string]$prop, [string]$expr) { if ($null -eq $item['Bindings']) { $item['Bindings'] = New-Dict }; $item['Bindings'][$prop] = New-NcBinding $expr }
function Get-Expr($item, [string]$prop) { $item['Bindings'][$prop]['Formula']['Expression'] }
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
# stretch a 20px-high row item to $R: full-height items grow, smaller ones (and images) are re-centred
function Set-RowHeight($item, [double]$old, [double]$new) {
  if ([double]$item['Height'] -eq $old -and $item['$type'] -notmatch 'ImageItem') { $item['Height'] = $new }
  else { $item['Top'] = [double]$item['Top'] + ($new - $old) / 2 }
  if ($item['Childrens']) { foreach ($c in $item['Childrens']) { if ([double]$c['Height'] -eq $old) { $c['Height'] = $new } else { $c['Top'] = [double]$c['Top'] + ($new - $old) / 2 } } }
}
function Get-Var($dash, [string]$name) { $dash['Variables']['DashboardVariables'] | Where-Object { $_['VariableName'] -eq $name } | Select-Object -First 1 }
function Add-Var($dash, [string]$name, [string]$jsExpr, [bool]$override = $false) {
  $v = New-Dict
  $v['VariableName'] = $name; $v['EvaluateOnlyOnce'] = $false; $v['OverrideWithParentDashboardVariableWhenAvailable'] = $override
  $x = New-Dict; $x['JSExt'] = 1; $x['Interpreter'] = 1; $x['Expression'] = $jsExpr
  $v['ValueExpression'] = $x; $v['EvaluateBeforeScreenRoles'] = $false
  $vars = New-Object System.Collections.ArrayList; $vars.AddRange(@($dash['Variables']['DashboardVariables'])); [void]$vars.Add($v)
  $dash['Variables']['DashboardVariables'] = $vars.ToArray()
}

# ---------------- JSON I/O (lossless, SimHub-compatible) ----------------
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

# ---------------- workflow ----------------
# validates the source, copies it to the target and ships the Inter font in _SHFonts
function Initialize-Target([string]$SourceDir, [string]$TargetDir, [string]$mainFile) {
  if ([IO.File]::ReadAllText((Join-Path $SourceDir $mainFile)).Contains('"Panel Shade 1"')) {
    throw "SourceDir already contains the iRacing style - point it at the original benofficial2 files (e.g. git checkout upstream/master -- <dir>)."
  }
  if ($SourceDir -ne $TargetDir) { Copy-Item (Join-Path $SourceDir '*') $TargetDir -Recurse -Force }
  # SimHub copies _SHFonts into its DashFonts folder when the dash is imported
  if ($Font -eq 'Inter' -and (Test-Path $fontDir)) {
    $shf = Join-Path $TargetDir '_SHFonts'; if (-not (Test-Path $shf)) { New-Item -ItemType Directory $shf | Out-Null }
    Copy-Item (Join-Path $fontDir 'Inter-*.ttf') $shf -Force
    Copy-Item (Join-Path $fontDir 'RobotoMono-*.ttf') $shf -Force
  }
  "Source: $SourceDir"; "Target: $TargetDir"; "Font:   $Font"
}
# keeps the dashboard metadata (embedded and/or separate .metadata file) in sync with the new base size
function Update-Metadata($dash, [string]$metaPath, [double]$w, [double]$h) {
  $dash['BaseWidth'] = [int]$w; $dash['BaseHeight'] = [int]$h   # integers, as in the originals
  if ($dash.ContainsKey('Metadata') -and $dash['Metadata']) { $dash['Metadata']['Width'] = [double]$w; $dash['Metadata']['Height'] = [double]$h }
  if (Test-Path $metaPath) {
    $meta = [IO.File]::ReadAllText($metaPath)
    $meta = [regex]::Replace($meta, '("Width":\s*)[0-9.]+', "`${1}$w.0")
    $meta = [regex]::Replace($meta, '("Height":\s*)[0-9.]+', "`${1}$h.0")
    [IO.File]::WriteAllText($metaPath, $meta, $utf8)
  }
}

# ---------------- iRacing look: building blocks ----------------
# Measured on the iRacing box at 100% opacity: a strictly linear vertical gradient from the top colour
# (benofficial2 'Background Color' setting, iRacing: #2B2B33) to #12121B, evenly bluish.
$PanelBottom = '#FF12121B'
$ShadeBands  = 48
function New-Layer([string]$name, [object[]]$children) {
  $o = New-Base 'Layer'
  $o['Group'] = $false; $o['Repetitions'] = 0; $o['Childrens'] = @($children)
  $o['Visible'] = $true; $o['BlinkPhasisInverted'] = $false; $o['Name'] = $name
  $o['RenderingSkip'] = 0; $o['MinimumRefreshIntervalMS'] = 0.0; $o['Opacity'] = 100.0
  $o['Bindings'] = New-Dict
  $o
}
# Nested bands in the bottom colour; band k covers [k/(N+1) .. bottom]. Opacities are chosen so the
# cumulative coverage grows linearly (= linear top->bottom gradient) without visible steps.
function Get-ShadeAlphas([int]$n) {
  $prevA = 0.0
  for ($k = 1; $k -le $n; $k++) {
    $a = ($k + 0.5) / ($n + 1)                       # coverage reached in band k (at its middle)
    [Math]::Round((1 - (1 - $a) / (1 - $prevA)) * 100, 3)
    $prevA = $a
  }
}
# Gradient fill (top colour + shade bands). $clipTopJs/$clipBottomJs (optional) restrict it to a vertical
# range while keeping the gradient aligned to the whole panel ($heightNc).
function New-GradientFill([string]$prefix, [string]$leftNc, [string]$widthNc, [string]$heightNc, [string]$clipTopJs = '', [string]$clipBottomJs = '', $radiusTop = $null, $radiusBottom = $null) {
  $alphas = @(Get-ShadeAlphas $ShadeBands)
  $base = New-Rect "$prefix Fill" 0 0 444 300 '#FF2B2B33' 100 $radiusTop
  Set-Js $base 'BackgroundColor' "return isnull(`$prop('benofficial2.BackgroundColor'), '#FF2B2B33')"
  Set-Nc $base 'Left' $leftNc; Set-Nc $base 'Width' $widthNc
  if ($clipTopJs) { Set-Js $base 'Top' "return $clipTopJs"; Set-Js $base 'Height' "return ($clipBottomJs) - ($clipTopJs)" }
  else { Set-Nc $base 'Height' $heightNc }
  $base
  for ($k = 1; $k -le $ShadeBands; $k++) {
    $b = New-Rect "$prefix Shade $k" 0 0 444 100 $PanelBottom $alphas[$k - 1] $radiusBottom
    Set-Nc $b 'Left' $leftNc; Set-Nc $b 'Width' $widthNc
    $start = "`$prop('variable.panelHeight') * $k / $($ShadeBands + 1)"
    if ($clipTopJs) {
      Set-Js $b 'Top' "return Math.max($clipTopJs, $start)"
      Set-Js $b 'Height' "return Math.max(0, ($clipBottomJs) - Math.max($clipTopJs, $start))"
    } else {
      Set-Nc $b 'Top' "$heightNc * $k / $($ShadeBands + 1)"
      Set-Nc $b 'Height' "$heightNc * ($($ShadeBands + 1) - $k) / $($ShadeBands + 1)"
    }
    $b
  }
}
# The panel lives in a layer whose opacity is the benofficial2 'Background Opacity' setting, so the whole
# gradient fades uniformly (like iRacing's opacity slider). A faint 1px border sits on top.
function New-PanelChrome([string]$opacityJs, [string]$widthNc, [string]$heightNc) {
  $fill = New-GradientFill 'Panel' '0' $widthNc $heightNc '' '' (New-Radius 8 8 8 8) (New-Radius 0 0 8 8)
  $bs = New-Radius 8 8 8 8
  $bs['BorderColor'] = '#09FFFFFF'; $bs['BorderTop'] = 1; $bs['BorderBottom'] = 1; $bs['BorderLeft'] = 1; $bs['BorderRight'] = 1
  $border = New-Rect 'Panel Border' 0 0 444 300 '#00000000' 100 $bs
  Set-Nc $border 'Width' $widthNc; Set-Nc $border 'Height' $heightNc
  $layer = New-Layer 'Panel' (@($fill) + @($border))
  Set-Js $layer 'Opacity' $opacityJs
  $layer
}
# iRacing draws some areas (Relative timing column) fully opaque, so they look lighter when the panel is translucent.
function New-OpaqueRegion([string]$name, [string]$leftNc, [string]$widthNc, [string]$topJs, [string]$bottomJs) {
  New-Layer $name @(New-GradientFill $name $leftNc $widthNc '[variable.panelHeight]' $topJs $bottomJs)
}
function New-Title([string]$text) { New-Text 'Title' 9 4 200 $R $text $Yellow 15.0 0 'Bold' }

# Footer cells: yellow label left, white value right. $cells = @(@('Label', 'jsTextExpr'), ...)
function New-FooterCells([object[]]$cells, [string]$widthNc) {
  $cols = $cells.Count
  $cw = "(($widthNc - $(2 * $PosLeft) - $(($cols - 1) * $CellGap)) / $cols)"
  for ($col = 0; $col -lt $cols; $col++) {
    $label = $cells[$col][0]; $expr = $cells[$col][1]
    $leftExpr = "$PosLeft + $col * ($cw + $CellGap)"
    $cellBg = New-Rect "$label Cell" 0 0 100 $R '#FFFFFFFF' 2.2 (New-Radius 4 4 4 4)   # iRacing: +5 over the panel
    Set-Nc $cellBg 'Left' $leftExpr; Set-Nc $cellBg 'Width' $cw
    $lab = New-Text "$label Label" 0 0 90 $R $label $Yellow $FootSize 0
    Set-Nc $lab 'Left' "$leftExpr + 12"; Set-Nc $lab 'Width' "$cw - 20"
    $val = New-Text "$label Value" 0 0 90 $R '' $TextWhite $FootSize 2
    Set-Nc $val 'Left' "$leftExpr + 12"; Set-Nc $val 'Width' "$cw - 20"
    Set-TimingMonospace $val
    Set-Js $val 'Text' $expr
    $cellBg; $lab; $val
  }
}

# Position cell: only left corners rounded, subtle +4% lift, solid yellow for the player. 1px hairline between rows.
function New-PosCell([string]$isPlayerJs) {
  $c = New-Rect 'Pos Cell' $PosLeft 0.5 $PosW ($R - 1) '#06FFFFFF' 100 (New-Radius 4 0 4 0)   # iRacing: +4 over the panel
  Set-Js $c 'BackgroundColor' "return ($isPlayerJs) ? '$Yellow' : '#06FFFFFF'"
  $c
}
# coloured badge (PIT, TOW, best/last lap) as a rounded pill, vertically inset like the rating badge
function Set-Pill($item) {
  $item['Top'] = 2.0; $item['Height'] = [double]($R - 4); $item['BorderStyle'] = New-Radius 4 4 4 4
}
# PIT / TOW inside benofficial2's 'Pit Status' group
function Set-PitPills($row) {
  $ps = Get-Child $row 'Pit Status'
  foreach ($n in 'Pit', 'Tow') { $p = Get-Child $ps $n; if ($p) { Set-Pill $p } }
}
# License/iRating badge like iRacing: larger, transparent fill, licence-coloured outline and text.
# $extra widens it (callers move the columns to its right by the same amount).
$RatingExtra = 12
function Set-RatingStyle($rating, [int]$extra = $RatingExtra) {
  # fill = licence (outline) colour at ~16% (measured: B #33CC00 -> #1F381C over the panel)
  $rating['BackgroundColor'] = '#00000000'
  $borderBinding = $rating['BorderStyle']['Bindings']['BorderColor']['Formula']
  $borderJs = $borderBinding['Expression']
  if ($borderBinding['Interpreter'] -ne 1) { throw 'rating border colour is not a JS binding' }
  Set-Js $rating 'BackgroundColor' "const c = String((function(){`r`n$borderJs`r`n})() || '');`r`nreturn c.length >= 7 ? '#29' + c.replace('#', '').slice(-6) : 'Transparent';"
  $rating['Top'] = 2.0; $rating['Height'] = [double]($R - 4); $rating['FontSize'] = 12.5
  foreach ($k in 'RadiusTopLeft', 'RadiusTopRight', 'RadiusBottomLeft', 'RadiusBottomRight') { $rating['BorderStyle'][$k] = 5 }
  $rating['Width'] = [double]$rating['Width'] + $extra
  $f = $rating['Bindings']['Width']['Formula']
  if ($f['Interpreter'] -eq 1) { $f['Expression'] = "return (function(){`r`n" + $f['Expression'] + "`r`n})() + $extra" }
  else { $f['Expression'] = '(' + $f['Expression'] + ") + $extra" }
}
# when the badge is hidden completely (offset -90) its extra width must be freed as well
function Update-RatingOffset($var, [int]$extra = $RatingExtra) {
  $x = $var['ValueExpression']
  $x['Expression'] = [regex]::Replace($x['Expression'], 'return offset\s*$', "return offset <= -90 ? offset - $extra : offset")
  if ($x['Expression'] -notmatch [regex]::Escape("offset - $extra")) { throw 'RatingOffset patch failed' }
}
# timing values in iRacing's monospace style
function Set-TimingMonospace($item) {
  $item['Font'] = $TimeFont; $item['FontWeight'] = $TimeWeight; $item['FontSize'] = $TimeSize
  $item['UseMonospacedText'] = $false
}
# Class timeline: glow fading right, 2px line, marker (square = $squareJs true, circle otherwise).
# The glow is 22 stacked 2px-stepped strips at 2% each (smooth, no visible blocks); they overlap neighbouring
# rows by 0.5px so no seams appear when scaled. $colorNc must be a cheap NCalc expression (e.g. a dashboard
# variable) because it is evaluated by ~25 items per row.
function New-ClassTimeline([string]$colorNc, [string]$squareJs) {
  for ($w = 44; $w -ge 2; $w -= 2) {
    $g = New-Rect "Class Glow $w" ($LineX + 2) -0.25 $w ($R + 0.5) '#FFFFFFFF' 2
    Set-Nc $g 'BackgroundColor' $colorNc
    $g
  }
  $line = New-Rect 'Class Line' $LineX -1 2 ($R + 2) '#FFFFFFFF' 100
  Set-Nc $line 'BackgroundColor' $colorNc
  $line
  $mk = 10
  foreach ($m in @(@('Marker Square', 2, $squareJs), @('Marker Circle', 5, "!($squareJs)"))) {
    $bs = New-Dict
    $bs['BorderColor'] = '#FFFFFFFF'; $bs['BorderTop'] = 2; $bs['BorderBottom'] = 2; $bs['BorderLeft'] = 2; $bs['BorderRight'] = 2
    $bs['RadiusTopLeft'] = $m[1]; $bs['RadiusTopRight'] = $m[1]; $bs['RadiusBottomLeft'] = $m[1]; $bs['RadiusBottomRight'] = $m[1]
    $bs['Bindings'] = New-Dict; $bs['Bindings']['BorderColor'] = New-NcBinding $colorNc
    $marker = New-Rect $m[0] ($LineX + 1 - $mk / 2) (($R - $mk) / 2) $mk $mk $MarkerFill 100 $bs
    Set-Js $marker 'Visible' "return $($m[2])"
    $marker
  }
}
# Car number: smaller, white digits (yellow for the player), '#' in class colour, no coloured box.
# Returns the extra '#' item; $numRightJs is the JS expression of the digits' right edge.
function Set-NumberStyle($num, [string]$numberJs, [string]$isPlayerJs, [string]$colorNc, [string]$numRightJs) {
  $num['BackgroundColor'] = '#00FFFFFF'; $num['TextColor'] = $TextWhite; $num['HorizontalAlignment'] = 2; $num['FontSize'] = $NumSize
  $pad = New-Dict; $pad['PaddingRight'] = 2; $num['TextPadding'] = $pad
  $num['UseMonospacedText'] = $true; $num['CharWidth'] = $NumChar; $num['SpecialCharsWidth'] = 4.0
  $num['Bindings'].Remove('BackgroundColor') | Out-Null
  Set-Js $num 'Text' "return '' + isnull($numberJs, '');"
  Set-Js $num 'TextColor' "return ($isPlayerJs) ? '$Yellow' : '$TextWhite';"
  $hash = New-Text 'Number Hash' ([double]$num['Left']) 0 9 $R '#' '#FFFFFFFF' $NumSize 2
  Set-Js $hash 'Left' "const n = ('' + isnull($numberJs, '')).length;`r`nreturn ($numRightJs) - $NumChar * n - 9;"
  Set-Nc $hash 'TextColor' $colorNc
  $hash
}
# Player row: muted gold wash with rounded corners (iRacing at 100%: +15/+11/-6 over the panel)
function Set-PlayerHighlight($hl, [string]$visibleJs, [string]$widthNc) {
  $hl['BackgroundColor'] = '#FF8A6E00'; $hl['Opacity'] = 15.0
  $hl['Left'] = 1.0; $hl['Top'] = 1.0; $hl['Height'] = [double]($R - 2)
  $hl['BorderStyle'] = New-Radius 4 4 4 4
  Set-Js $hl 'Visible' $visibleJs
  Set-Nc $hl 'Width' $widthNc
}
