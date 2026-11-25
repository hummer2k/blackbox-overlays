# iRacing style for benofficial2 overlays

Restyles benofficial2's overlays so they match the native iRacing (2025 UI) black boxes:
one continuous rounded panel with a 1px border and a top-to-bottom shade, yellow `RELATIVE`
title, class timeline with markers and class-colour glow, left-rounded position cells,
right-aligned fixed-pitch timing column, off-white text (`#F2F2F3`) and the Inter font.

Currently covered: **Relative** (`Set-IracingStyleRelative.ps1`).

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

The script refuses to run on files that are already styled.

## Apply to a local SimHub installation

Point `-SourceDir` at an unmodified copy of the overlay and `-TargetDir` at SimHub's dash folder:

```powershell
.\tools\iracing-style\Set-IracingStyleRelative.ps1 `
    -SourceDir "C:\path\to\original\benofficial2 - iRacing Relative" `
    -TargetDir "C:\Program Files (x86)\SimHub\DashTemplates\benofficial2 - iRacing Relative"
```

SimHub loads dash fonts from its global `DashFonts` folder. Importing the dash copies
`_SHFonts` there automatically; when copying files manually, also copy
`fonts\Inter-*.ttf` to `C:\Program Files (x86)\SimHub\DashFonts` and restart SimHub
(or run the script with `-Font 'Segoe UI'`).

The overlay's base size changes (Relative: 500x266 -> 535x328), so resize the overlay
window once in SimHub's overlay layout editor to avoid distortion.

## Notes

- Position cells stay empty while benofficial2 has no live class position for a car
  (out lap, no timed lap, in pits) - same as the original overlay.
- Fonts: Inter by The Inter Project Authors, SIL Open Font License 1.1 (`fonts/LICENSE-Inter.txt`).
