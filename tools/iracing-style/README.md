# iRacing style

Restyles benofficial2's original overlays so they match the native iRacing (2025 UI) black boxes:
one continuous rounded panel with a 1px border and a top-to-bottom shade, yellow title, class timeline
with markers and class-colour glow, left-rounded position cells, right-aligned monospace timing column,
off-white text (`#F2F2F3`) and the Inter font.

These scripts are run by [`tools\Build-Overlays.ps1`](../Build-Overlays.ps1), which exports the originals
from benofficial2's repository, applies the style and then rebrands the result for the Blackbox plugin.
They work on the **upstream** names (`benofficial2 - iRacing ...`, `benofficial2.*` properties); the
rebranding happens afterwards in `tools\Blackbox.Branding.ps1`.

| Overlay | Script | Notes |
|---|---|---|
| Relative | `Set-IracingStyleRelative.ps1` | weather in the header (taken from benofficial2's Precipitation / Track Wetness / Wind widgets); footer: Inc, SOF, Track |
| Multi-Class Standings | `Set-IracingStyleStandings.ps1` | per-class grouping kept; title `STANDINGS`; footer: Lap, Left |
| Spotter | `Set-IracingStyleSpotter.ps1` | black-box columns (opacity = Relative's Background Opacity), yellow bars, recoloured blind spot icon |

Shared look (palette, metrics, panel, footer cells, position cell, class timeline, car number,
lossless JSON writer) lives in `IracingStyle.Common.ps1`, so all overlays stay consistent.
The scripts never edit by hand-made patches; they transform the original files, and they refuse to run
on files that are already styled.

## Fonts

SimHub loads dash fonts from its global `DashFonts` folder. The scripts put Inter and Roboto Mono into each
overlay's `_SHFonts`; `tools\Install-Blackbox.ps1` copies them to `DashFonts`.

- Inter by The Inter Project Authors (`fonts/LICENSE-Inter.txt`) - names, labels, positions
- Roboto Mono by The Roboto Mono Project Authors (`fonts/LICENSE-RobotoMono.txt`) - timing values,
  like iRacing's separate monospace timing font

Both are licensed under the SIL Open Font License 1.1.

## Icons

`New-IracingTyreIcons.ps1` renders iRacing-style tyre icons into `images/` (currently the wet tyre:
dark disc, dark blue ring `#0159CF`, white W). Copies live in the repo's `Images/Icons`, which
`Install-Blackbox.ps1` installs to `ImageLibrary\Blackbox\Icons`.

## Notes

- Base sizes: Relative 575x328, Multi-Class Standings 736x846 (originals 500x266 and 690x695) - resize the
  overlay windows once in SimHub's overlay layout editor if they look distorted.
- Position cells stay empty while the plugin has no live class position for a car
  (out lap, no timed lap, in pits) - same as the original overlay.
