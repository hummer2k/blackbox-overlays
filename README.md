# Blackbox Overlays

SimHub overlays for iRacing that look like iRacing's own (2025 UI) black boxes, with the extra data
of a SimHub plugin:

| Overlay | What it shows |
|---|---|
| **Relative** | Cars ahead and behind on track, class timeline, iRating/licence, tyres, pit status, gap. Weather (precipitation, track wetness, wind) in the header; incidents, SOF and track temperature in the footer. |
| **Multi-Class Standings** | Live leaderboard grouped by car class, with best/last lap, gaps and stint info. Lap and laps left in the footer. |
| **Spotter** | Side-by-side bars next to the mirror and a rejoin helper when you are stopped or off track. |

Everything else (fuel, delta, inputs, track map, ...) is left to the iRacing UI.

> **Based on [benofficial2's Official Overlays](https://github.com/fixfactory/bo2-official-overlays).**
> The plugin's data logic and the original overlays are benofficial2's work. Blackbox trims the collection
> down to the three overlays above, restyles Relative and Multi-Class Standings like iRacing's black boxes and
> ships the plugin under its own name. Please report Blackbox issues here, not to benofficial2.

## Install

Requirements: [SimHub](https://www.simhubdash.com/download-2/) 9.12.8 or later, Windows PowerShell.

**From a release (no build tools needed):** download `Blackbox-Overlays-<version>.zip` from the
[releases](https://github.com/hummer2k/blackbox-overlays/releases), unzip it, close SimHub and double-click
`Install.cmd`. When switching over from benofficial2's plugin, run it once from a terminal as
`Install.cmd -MigrateFromBenofficial2` instead (see step 2 below for what that does).

**From the repository:**

1. Build the plugin (see below) - this produces `Plugin\Blackbox.Plugin\bin\Release\Blackbox.Plugin.dll`.
2. Close SimHub and run:

   ```powershell
   .\tools\Install-Blackbox.ps1 -MigrateFromBenofficial2
   ```

   This copies the overlays, fonts, images and the plugin into SimHub. `-MigrateFromBenofficial2` is only
   needed once when switching over from benofficial2's plugin: it takes over your plugin settings and overlay
   window positions and moves benofficial2's plugin and overlays into a `_Backup_benofficial2_<date>` folder
   (nothing is deleted - both plugins would otherwise compute the same data twice).
3. Start SimHub, enable the **Blackbox Plugin** when asked and turn on *Show in left main menu* to reach its
   options.

Later updates: `git pull`, rebuild the plugin, close SimHub, run `.\tools\Install-Blackbox.ps1`.

## Building the plugin

The plugin is a .NET Framework 4.8 class library that references SimHub's DLLs.

- Install the **Visual Studio 2022 Build Tools** (or Visual Studio) with the *.NET desktop build tools*
  workload and the *.NET Framework 4.8 targeting pack*.
- Set `SIMHUB_INSTALL_PATH` to SimHub's folder **with a trailing backslash**, e.g.
  `C:\Program Files (x86)\SimHub\`.
- In a *Developer PowerShell for VS 2022*:

  ```powershell
  msbuild Plugin\Blackbox.Plugin.sln -t:restore -p:RestorePackagesConfig=true
  msbuild Plugin\Blackbox.Plugin\Blackbox.Plugin.csproj -p:Configuration=Release -p:SolutionDir="$PWD\Plugin\\" -p:PostBuildEvent=
  ```

  `-p:PostBuildEvent=` skips the post-build step that would copy the DLL straight into `SIMHUB_INSTALL_PATH`;
  `tools\Install-Blackbox.ps1` does that instead.

Tests (need the .NET SDK on `PATH`):

```powershell
msbuild Plugin\Blackbox.Tests\Blackbox.Tests.csproj -p:Configuration=Release -p:SolutionDir="$PWD\Plugin\\" -p:PostBuildEvent=
dotnet test Plugin\Blackbox.Tests\bin\Release\net48\Blackbox.Tests.dll
```

## CI and releases

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on every push to `main` and on pull requests:

- builds the plugin and the tests against SimHub's DLLs (downloaded from
  [SimHub's GitHub releases](https://github.com/SHWotever/SimHub/releases) and cached; they are only compile
  references and are never shipped),
- runs the tests,
- rebuilds the overlays with `tools\Build-Overlays.ps1` and fails if `Overlays/` differs from the committed files,
- packs the release zip (`tools\ci\New-ReleasePackage.ps1`), downloadable as a build artifact.

To publish a release:

1. Set the new version in `Plugin/Blackbox.Plugin/Version.cs` (`CurrentVersion`, `BetaVersion = ""`) and in
   `Versions.json` (`plugin`) - the update check in SimHub compares these.
2. Commit, then tag and push: `git tag v1.1; git push origin main v1.1`.
3. The workflow checks that the tag matches both files, builds everything and creates the GitHub release with
   the zip and generated release notes.

## Repository layout

| Path | Content |
|---|---|
| `Overlays/` | The three overlays, **generated** by `tools\Build-Overlays.ps1` - don't edit by hand |
| `Plugin/` | The Blackbox SimHub plugin (properties `Blackbox.*`, settings `PluginsData\Common\Blackbox.*.json`) |
| `Images/` | Car logos, flags and tyre icons, installed to `ImageLibrary\Blackbox` |
| `tools/Build-Overlays.ps1` | Rebuilds `Overlays/` from benofficial2's originals: iRacing style + rebranding |
| `tools/Install-Blackbox.ps1` | Installs into SimHub |
| `tools/iracing-style/` | The iRacing look (scripts, Inter/Roboto Mono fonts, icons) - see its [README](tools/iracing-style/README.md) |
| `tools/upstream-ref.txt` | The benofficial2 commit the overlays are built from |
| `tools/ci/` | CI helpers: SimHub reference DLLs, release zip, release version check |

### Taking over changes from benofficial2

The `upstream` remote points at benofficial2's repository.

```powershell
git fetch upstream
.\tools\Build-Overlays.ps1 -UpstreamRef upstream/master   # overlays
git diff --stat                                           # check, then test in SimHub
```

If the result is good, write the new commit hash into `tools\upstream-ref.txt`. Plugin changes have to be
merged by hand (`git diff <old ref> upstream/master -- Plugin/benofficial2.Plugin`), since the plugin was
renamed and trimmed here.

Car, track and flair data (`Data/*.json`) are still downloaded at runtime from benofficial2's repository,
so new cars and tracks keep working without a Blackbox update.

## Credits & licence

- **benofficial2** - [benofficial2's Official Overlays](https://github.com/fixfactory/bo2-official-overlays),
  Copyright (C) 2023-2026 benofficial2. Blackbox is a modified version of it.
- **Wotever** - [SimHub](https://www.simhubdash.com/).
- **Romainrob** - [iRacing Extra Properties](https://www.simhubdash.com/community-2/dashboard-templates/romainrobs-collection/),
  credited by benofficial2 as an inspiration.
- Fonts: [Inter](https://rsms.me/inter/) and [Roboto Mono](https://fonts.google.com/specimen/Roboto+Mono),
  both SIL Open Font License 1.1 (`tools/iracing-style/fonts`).

Blackbox is free software under the **GNU General Public License v3** (see [LICENSE](LICENSE)), like the
project it is based on. All changes compared to benofficial2's version are in this repository's git history.

"iRacing" is a trademark of iRacing.com Motorsport Simulations, LLC. This project is not affiliated with
or endorsed by iRacing or benofficial2.
