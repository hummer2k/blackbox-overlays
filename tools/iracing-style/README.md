# iRacing style for benofficial2 overlays

Restyles benofficial2's overlays so they match the native iRacing (2025 UI) black boxes:
one continuous rounded panel with a 1px border and a top-to-bottom shade, yellow `RELATIVE`
title, class timeline with markers and class-colour glow, left-rounded position cells,
right-aligned fixed-pitch timing column, off-white text (`#F2F2F3`) and the Inter font.

Currently covered:

| Overlay | Script | Notes |
|---|---|---|
| Relative | `Set-IracingStyleRelative.ps1` | footer: Inc, SOF, Track |
| Multi-Class Standings | `Set-IracingStyleStandings.ps1` | per-class grouping kept; title `STANDINGS`; footer: Lap, Left |

Shared look (palette, metrics, panel, footer cells, position cell, class timeline, car number,
lossless JSON writer) lives in `IracingStyle.Common.ps1`, so all overlays stay consistent.

The scripts never edit by hand-made patches; they transform the **original** benofficial2 files.
That keeps the style re-applicable after every upstream update.

## Apply / re-apply after an upstream update

```powershell
git fetch upstream
git merge upstream/master            # or rebase the iracing-style branch

# reset the overlay to the upstream original, then restyle it
git checkout upstream/master -- "Overlays/benofficial2 - iRacing Relative"
.\tools\iracing-style\Set-IracingStyleRelative.ps1 `
    -SourceDir "Overlays\benofficial2 - iRacing Relative" `
    -TargetDir "Overlays\benofficial2 - iRacing Relative"
```

Same for the standings (`Set-IracingStyleStandings.ps1` on
`Overlays/benofficial2 - iRacing Multi-Class Standings`).
The scripts refuse to run on files that are already styled.

## Apply to a local SimHub installation

Point `-SourceDir` at an unmodified copy of the overlay and `-TargetDir` at SimHub's dash folder:

```powershell
.\tools\iracing-style\Set-IracingStyleRelative.ps1 `
    -SourceDir "C:\path\to\original\benofficial2 - iRacing Relative" `
    -TargetDir "C:\Program Files (x86)\SimHub\DashTemplates\benofficial2 - iRacing Relative"
```

SimHub loads dash fonts from its global `DashFonts` folder. Importing the dash copies
`_SHFonts` there automatically; when copying files manually, also copy
`fonts\*.ttf` to `C:\Program Files (x86)\SimHub\DashFonts` and restart SimHub
(or run the script with `-Font 'Segoe UI'`).

The overlays' base sizes change (Relative: 500x266 -> 535x328, Multi-Class Standings:
690x695 -> 710x846), so resize the overlay windows once in SimHub's overlay layout editor
to avoid distortion.

## Notes

- Position cells stay empty while benofficial2 has no live class position for a car
  (out lap, no timed lap, in pits) - same as the original overlay.
- Fonts (both SIL Open Font License 1.1, shipped in each overlay's `_SHFonts`):
  - Inter by The Inter Project Authors (`fonts/LICENSE-Inter.txt`) - names, labels, positions
  - Roboto Mono by The Roboto Mono Project Authors (`fonts/LICENSE-RobotoMono.txt`) - timing values,
    like iRacing's separate monospace timing font
