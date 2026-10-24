# Environment: installation (one-time)

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Environment (one-time)

This order worked.

### 1. Visual Studio 2022 Build Tools
Not VS 2026. The IDE is not needed, because `Build.bat` works without a `.sln`.

Required components:
- `Microsoft.VisualStudio.Workload.VCTools`
- `Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools`
- `Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64`, that is MSVC **14.38.33130**. 14.44 alone is not enough.
- `Microsoft.Net.Component.4.8.1.SDK`
- Windows 11 SDK

The docs' Linux CI setup pins the same toolset: `--msvc-version 17.8`, `--sdk-version 10.0.22621`, channel `release.ltsc.17.8` (docs.ficsit.app, Development → Linux setup). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**[?]** Rules for Visual Studio users from the docs (not tried here, because this setup builds without the IDE): never use "Build Solution", build only the `FactoryGame` project (Development Editor, Win64); never enable "Visual Studio Integration Tool" or "Unreal Engine Test Adapter" in the UE Integration Configuration tab (the docs say it breaks editor and packaging builds, and the repair is a reinstall); VS 2026 breaks the Create C++ Class wizard; do not update the NuGet packages flagged as vulnerable; rebuild the Development Editor with the editor closed, because hot reload crashes. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

Check whether a component is installed:
```
vswhere -products * -requires <id> -property installationPath
```

Install a missing one (as administrator):
```
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add <id> --passive --norestart
```

The engine brings its own dotnet (8.0.300).

### 2. Access to the CSS engine
- Link your GitHub account to Epic: https://www.unrealengine.com/ue-on-github. The invitation to the EpicGames organization arrives by email. You must accept it.
- Log in at https://linker.ficsit.app/link.
- Until you have access, `gh api repos/satisfactorymodding/UnrealEngine` returns 404. This is a good test.

### 3. Installing the engine
```
gh release download 5.6.1-css-83 -R satisfactorymodding/UnrealEngine -p UnrealEngine-CSS-Editor-Win64.exe -p "UnrealEngine-CSS-Editor-Win64-*.bin"
```
- About 5 GB in total. The `-2.bin` file is exactly 2 147 483 647 B, and that is expected. Compare sizes with those in the release instead of assuming the file was cut off.
- The installer is an unsigned Inno Setup. Silent install, as administrator, about 20 min:
  ```
  UnrealEngine-CSS-Editor-Win64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="D:\UE\UE_5.6-CSS" /LOG=install.log
  ```
- The installer registers `HKCU\Software\Epic Games\Unreal Engine\Builds` → `5.6.1-CSS`. This matches `"EngineAssociation": "5.6.1-CSS"` in `FactoryGame.uproject`.
- After installation you can delete the installer files (about 5.5 GB).

### 4. Wwise 2025.1.6.9117 (starter project `master` with headers 513885)
Required even without audio, because the project enables the `Wwise` and `WwiseNiagara` plugins.
- The Audiokinetic site blocks scripts (403), so you need the Audiokinetic Launcher and a login.
- In the Launcher: Wwise → Latest → All → 2025.1.6 → 2025.1.6.9117.
  - Packages: Authoring and SDK (C++).
  - Deployment platforms: Linux and Microsoft → Windows → Visual Studio 2019 and 2022 (the set used in the verified procedure, step 5, the bullet on moving an existing starter project).
  - **[?]** The docs also list Game Core. The verified procedure did not install it, and the SML CI installs only `Windows_vc160`, `Windows_vc170` and `Linux` (`.github/workflows/build.yml:176-178`), so whether Game Core is needed is not settled. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
  - Plugins: none. The Launcher pre-ticks several (Mastering Suite, Reflect, Soundseed Air, Auro Headphone, iZotope suite, McDSP); untick them all.
- Use an install path without spaces, e.g. `D:\Audiokinetic\Wwise_2025.1.6.9117`.
- The integration version is 2025.1.6.4248 (`Plugins/Wwise/Wwise.uplugin` `VersionName` 2025.1.6.9117.4248), the one the SML CI uses. The docs and the starter project's `Mods/WwisePatches/Patches/04-CSS-CL503514.patch` agree with this version. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **Older starter project `master` (headers 502094, patches `04-CSS-CL480605`):** Wwise **2023.1.14.8770**. Launcher: Wwise → Latest → All → 2023.1 → 2023.1.14.8770; packages Authoring and SDK (C++); platforms Linux, VS2019, VS2022, Game Core; no plugins; path e.g. `D:\Audiokinetic\Wwise_2023.1.14.8770`. The Wwise patches fit exactly one Wwise version (step 6), so the version follows the branch.

### 5. Starter project
The SML repository `satisfactorymodding/SatisfactoryModLoader` is the `FactoryGame.uproject` project. It contains:
- the game headers in `Source/FactoryGame`,
- `Mods/SML`, `Mods/SMLEditor`, `Mods/Alpakit`, `Mods/AccessTransformers`,
- `Mods/GameFeatures/ExampleMod`.

The SML version in the project must be the one the game has (3.12.0 here).

**Which branch to clone.** The documentation (the *StarterProjectViaClone* page) says to take `master` or `dev`, whichever was updated last. The date alone is not enough, because the branches differ in Wwise version:
- Example from 2026-10: `master` (`d2162c9`) had headers 502094 and patches for Wwise 2023.1.14. `dev`, 4 commits newer, had the same headers, but patches for Wwise 2025.1.6 and for a future game changelist 503514. For game 502094, `master` was the right one.
- The Wwise version of a branch shows in the file names in `Mods/WwisePatches/Patches` (e.g. `04-CSS-CL480605.patch` or `04-CSS-CL503514.patch`). To see the differences between branches: `gh api repos/satisfactorymodding/SatisfactoryModLoader/compare/master...dev --jq '.files[].filename'`.
- The game headers must have the changelist of the installed game. Compare `Source/FactoryGame/currentVersion.txt` with `<Game>\Engine\Binaries\Win64\*.version` (field `Changelist`). The SML version does not tell you this: SML 3.12.0 had headers 491125, and later 502094.
- **[source]** A mod built on older headers may have a wrong virtual function layout. Between 491125 and 502094 the `AFGBuildable` class changed its set of virtual functions, so virtual function calls and hooks on buildables would hit the wrong place.
- docs.ficsit.app says to take whichever of `master` and `dev` was pushed last; the header changelist and the Wwise patches above decide. On 2026-10-24 `master` was `8eebc9e` (headers 513885 = the installed game, Wwise 2025.1.6 patches). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- Clone `master`: `git clone -b master https://github.com/satisfactorymodding/SatisfactoryModLoader.git <Project>`, about 1.5–3 min.
- **[source]** Game changelist 513885 (Steam, branch `rel-main-anniversary-2026`, installed by Steam on 2026-10-12) differs from 502094 in four game headers only (SML `master` commit "Update headers to CL513885": `FGGameState.h`, `FGSignSubsystem.h`, `Buildables/FGBuildableConveyorBase.h`, `Hologram/FGSplineBuildableSnapHologram.h`), and the same `master` also carries the Wwise 2025.1.6 patches (`04-CSS-CL503514.patch`), so moving the starter project to it means the Wwise upgrade too. The one layout change that matters: `AFGGameState` gained `mOnSignSubsystemReplicated` (`FOnSingleSubsystemReplicatedDelegate`) right after `mOnVehicleSubsystemReplicated`, which moves every later member, `mCheatNoPower` among them. A mod built on the 502094 headers still loads and runs on 513885 with SML 3.12.0 (a mod's whole scenario set passed on it), but an inline accessor compiled into the mod, such as `AFGGameState::GetCheatNoPower()` (`FORCEINLINE`, `FGGameState.h:278`), reads the member's old offset, i.e. bytes of another member, with no error or warning. The game update is visible only in the log line `LogInit: Build: ++FactoryGame+rel-main-anniversary-2026-CL-513885`. Evidence: `git diff d2162c9 8eebc9e -- Source/FactoryGame/Public` in the SML repository, game log of 2026-10-12. The docs (Linux setup and CI pages, `.github/workflows/build.yml`) also tie the Wwise 2025.1.6 patches to this `master`. (2026-10-13, game 513885, SML 3.12.0; 2026-10-24, docs.ficsit.app)
- Moving an existing starter project from `master` `d2162c9` (headers 502094, Wwise 2023.1.14) to `master` `8eebc9e` (headers 513885, Wwise patches `04-CSS-CL503514`) works this way, with the editor closed: move `Plugins/Wwise`, `Plugins/WwiseNiagara` and `<Project>_WwiseProject/` out of the project (a backup, and the Launcher then offers a fresh integration), `git checkout -- Config/DefaultGame.ini` (the old integration's local change conflicts with the upstream change of that file), `git merge --ff-only origin/master`; install Wwise **2025.1.6.9117** in the Audiokinetic Launcher (Authoring and SDK (C++); Deployment Platforms Linux and Microsoft → Windows → Visual Studio 2019 and 2022). The Launcher pre-ticks several plugins (Mastering Suite, Reflect, Soundseed Air, Auro Headphone, iZotope suite, McDSP); none is needed, untick them all. Then Unreal Engine tab → the project → Integrate Wwise in Project… → 2025.1.6.9117, Wwise project "New project". The integration writes `Plugins/Wwise` (`VersionName` 2025.1.6.9117.4248, the integration version the SML CI uses), `Plugins/WwiseNiagara`, `Plugins/WwiseSoundEngine`, `Plugins/WwiseMotionOpenXRHelpers` and a new `<Project>_WwiseProject/`, rewrites `WwiseProjectPath` and moves the `[/Script/WwisePackaging.WwisePackagingSettings]` section of `DefaultGame.ini` (its value stays). The next `FactoryEditor` build applied the patches 01, 03, 04-CSS-CL503514, 05 and 06 by itself and compiled in 8.5 min; the first mod packaging afterwards, game code included, took about 7 min. A mod built this way loads and passes its scenario set on game 513885 (`LogInit: Build: …-CL-513885`). Evidence: build logs and test runs of 2026-10-13. (2026-10-13, game 513885, SML 3.12.0, Wwise 2025.1.6.9117)
- **`<Game>\CommunityResources`** (in the game install) holds `Headers.zip` (the headers of the installed build), `FactoryGame.usmap`, `CustomVersions.json` (UTF-16 LE), `Docs\en-US.json` (UTF-16, about 10 MB, the native class and property documentation) and `DedicatedServerAPIDocs.md`. **[source]** Use `Headers.zip` to confirm the installed game's headers when the starter project lags a game update: its `FGGameState.h` was identical to the starter project's except for the injected `#include "FactoryGame.h"` (one header compared; the zip was dated 12 Oct, the day of game 513885). The base-game assets in the starter project's `Content` are data-only placeholders (for example `Desc_IronRod.uasset`, 6.8 KB), so editing them changes nothing in the game (files read on disk; the effect in the game was not tested). **[?]** The docs say asset types without a placeholder (animations, particles) come out blank in the cook. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

### 6. Project location first, then the Wwise integration
The integration writes `Plugins/Wwise`, `Plugins/WwiseNiagara` and `<Project>_WwiseProject/` into the project, and it also rewrites `WwiseProjectPath` in `Config/DefaultGame.ini`. So the project must already be in its final location.

- **[?]** Location rules from the docs (not tried here, the project's path complies): not in Downloads, Desktop, Documents or a cloud-synced folder (corruption); no unicode or special characters in any part of the path (`Something.pch : No such file`); a short path (long file names while packaging); an SSD; 30+ GB free. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[?]** Wwise integration traps from the docs (not met here): sign in to the Audiokinetic Launcher first (otherwise the errors are ambiguous); never press the Wwise "update" buttons on the Unreal Engine tab; when the version is missing from the list, set the dropdown to All and check that `EngineAssociation` is `5.6.1-CSS`; on a checksum error install a nearby 2025.1.6.* version. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

- Moving the project: `robocopy src dst /E /MT:16`. An exit code below 8 means success.
- Integration in the Launcher:
  1. Unreal Engine tab → Open other → `FactoryGame.uproject`.
  2. Integrate Wwise in Project… → version 2025.1.6.9117 (2023.1.14.8770 on the older `master`, step 4).
  3. Wwise Project: "New project". The field is red, because the config points to a nonexistent `SatisfactoryMod_WwiseProject`. This is normal.
- The integration names the Wwise project after the folder: in the `StarterProject` folder it created `StarterProject_WwiseProject`. `RootOutputPath` in `DefaultGame.ini` stays at `SatisfactoryModLoader_WwiseProject`. Leave the modified `DefaultGame.ini` as it is.
- Without the soundbank generation from the documentation, building and packaging worked (two projects). docs.ficsit.app (project_setup) says to generate the sound banks and to set the Root Output Path and Unreal Audio Routing = Both; in this setup `RootOutputPath` stayed at `../SatisfactoryModLoader_WwiseProject/...` (`DefaultGame.ini:555`), `AudioRouting=Custom` (`:582`) and there is no `GeneratedSoundBanks` folder, and the editor and packaging still worked; the docs' steps only silence a popup. When merging the integration's rewrite of `DefaultGame.ini`, keep `bPackageAsBulkData=True` in `[/Script/WwisePackaging.WwisePackagingSettings]` (`:545-550`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **The build applies the Wwise patches itself.** `Mods/WwisePatches/WwisePatches.uplugin` has the script `applyPatches.ps1` in `PreBuildSteps`. It applies `Patches/*.patch` to `Plugins/Wwise` and records the applied ones in `Plugins/Wwise/applied_patches.txt`. You need to do nothing by hand. The patches fit one Wwise version, so a version other than the one from the branch will not build.

### 7. Linux toolchain (optional, for server builds)
- File: `https://cdn.unrealengine.com/CrossToolchain_Linux/v25_clang-18.1.0-rockylinux8.exe` (946 MB, signed by Epic).
- Silent install: `/S /D=D:\UnrealToolchains\v25_clang-18.1.0-rockylinux8`.
- The installer sets the system-wide variable `LINUX_MULTIARCH_ROOT`. Only newly opened consoles see it.

### 8. First editor compile
Compiles FactoryGame, SML, Wwise and the mods. docs.ficsit.app (project_setup) says to generate a `.sln` and build the `FactoryGame` project in Visual Studio; that route is optional, because `Source/FactoryEditor.Target.cs` exists and `Build.bat` needs no `.sln`:
```powershell
& "<UE-CSS>\Engine\Build\BatchFiles\Build.bat" FactoryEditor Win64 Development -Project="<Project>\FactoryGame.uproject" -WaitMutex *> build-editor.log
```
- The time of the first compile varies a lot. Measurements on the same computer (14 physical cores, 16 GB RAM):
  - older project: 1929 actions, about 1.7 h, one action at a time (UBT reserves 1.5 GB per action),
  - fresh `master` clone from 2026-10: 365 actions, 21 min, `Executing up to 14 processes, one per physical core` with the local Unreal Build Accelerator. The cause of the difference is not known.
- UBT chooses the number of processes at the start (line `Determining max actions to execute in parallel`), so close the browser, Docker and WSL before the compile, not during it.
- Do not kill `dotnet.exe` processes from the engine folder during compiling or packaging: that is UnrealBuildTool itself.
- Output: `Binaries/Win64/UnrealEditor-FactoryGame.dll`, and for mods with C++ `Mods/.../Binaries/Win64/UnrealEditor-<Mod>.dll`. A mod with assets only (e.g. `ExampleMod`) has no DLL.

### 9. First editor launch
- Takes about 17 min (`LogUnrealEdMisc: Total Editor Startup Time, took 1017`), mainly because of shader compilation in several `ShaderCompileWorker` processes. Later launches are fast.
- Editor log: `<Project>\Saved\Logs\FactoryGame.log`.
- **Double-clicking `FactoryGame.uproject` may not open the CSS editor.** `.uproject` files are opened by `UnrealVersionSelector.exe` from the Epic Games Launcher, which answers "No Unreal Engine installations found. Would you like to locate one manually?", even though the engine is registered in `HKCU\Software\Epic Games\Unreal Engine\Builds` as `5.6.1-CSS` (step 3, "Installing the engine"). The cause is unknown. Launching directly works: `<UE-CSS>\Engine\Binaries\Win64\UnrealEditor.exe "<Project>\FactoryGame.uproject"`. **[source]** `<UE-CSS>\SetupScripts\Register.bat` only writes the value `5.6.1-CSS` (the engine folder with forward slashes) under `HKCU\Software\Epic Games\Unreal Engine\Builds`, and `Unregister.bat` removes it; a machine that already has exactly that value shows the problem anyway, so a missing registration is not the cause. The docs add that stale or duplicate entries there make the version picker ask. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **Alpakit in the editor.** Alpakit adds two icons to the toolbar, after the Play group and next to **Platforms**: **Alpakit Dev** (an alpaca) and **Alpakit Release** (a rocket). The same windows and **Alpakit Log** are in the **File** menu, in the project section. The mod wizard is the **Create Mod** button in the **Alpakit Dev** window. Templates: Blueprint Only, C++ & Blueprint, Blueprint Library (Advanced), C++ & Blueprint Library (Advanced). The first two create a game feature mod. The wizard warns that the plugin name (the mod reference) cannot be changed later. Source: `Mods/Alpakit/Source/Alpakit/Private/Alpakit.cpp`, `AlpakitDevWidget.cpp`, `Mods/Alpakit/Templates/templates.json` and the editor itself.
- **In UE 5.6 the bottom file panel is called Content Drawer, not Content Browser.** A mod's content is in it under `Plugins` → `<Mod> Content`. If `Plugins` is not visible, enable **Settings** → **Show Plugin Content**. Instructions for the user should use the name shown in the editor.
- Normal errors in this log: `LogWwiseProjectDatabase: Error: No JSON Metadata file found … GeneratedSoundBanks/Windows` and `LogWwiseResourceCooker: Error: GetInitBankCookedData … No data for platform` (no soundbanks), and also `LogAutomationTest: Error: … StructProperty … is not initialized properly` for structs from the game headers.

### 10. Moving the editor cache off drive C: (optional)
The editor's cache (Zen DDC) grows on drive C:, but it can be moved.
- The data is in `%LOCALAPPDATA%\UnrealEngine\Common\Zen\Data` (`BaseEngine.ini`, `[Zen.AutoLaunch] DataPath=%ENGINEVERSIONAGNOSTICINSTALLEDUSERDIR%Zen/Data`). After the first editor start and one packaging it took 0.5 GB. Zen cleans it up by itself only when less than 2 GB is left on the drive (`--gc-low-diskspace-threshold`).
- Verified method: with the editor closed, copy the folder to another drive, compare the file count and the total size, delete the original and create a directory junction in its place (`New-Item -ItemType Junction`). The same was done with `%USERPROFILE%\.nuget\packages` (1.8 GB of .NET packages, used by UBT among others).
- The junction works at once for every process, and the data moves with the folder, so shaders are not compiled again.
- **[source]** The engine-settings way is the environment variable `UE-LocalDataCachePath` (`LocalDataCachePathEnvOverride` in `[Zen.AutoLaunch]`). It works only in processes started after it is set, and it does not move existing data.
