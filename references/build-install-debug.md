# Build, packaging, installation, logs and diagnostics

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 8. Build and packaging

Alpakit in the editor is only a wrapper around RunUAT `PackagePlugin`. Calling it directly is faster:
```powershell
& "<UE-CSS>\Engine\Build\BatchFiles\RunUAT.bat" -ScriptsForProject="<Project>\FactoryGame.uproject" PackagePlugin `
  -project="<Project>\FactoryGame.uproject" -clientconfig=Shipping -serverconfig=Shipping -utf8output `
  -DLCName=<Mod> -build -platform=Win64 -nocompileeditor -installed -merge -Target=FactoryGameSteam *> package.log
```

**Flags**
- Without `-Target` it builds both targets, `FactoryGameEGS` and `FactoryGameSteam`. `-Target=FactoryGameSteam` halves local test time.
- Servers: `-server -serverplatform=Win64+Linux`. Linux needs the toolchain from section 2.7 (`references/setup.md`).

**Times**
- First Shipping packaging: 21–47 min. A mod with assets only in a fresh project: 21 min (game compile 297 actions in 700 s, cook 497 s, UnrealPak a few seconds).
- Later runs, when only the mod changes: 1.3–5 min. Group your changes and compile once.

**How to read the result**
- Success: `Result: Succeeded`, `BUILD SUCCESSFUL`, `AutomationTool exiting with ExitCode=0`.
- Compile error: `Result: Failed (OtherCompilationError)`, `BUILD FAILED`, ExitCode=6.
- Error details: `%APPDATA%\Unreal Engine\AutomationTool\Logs\<engine path>\UBA-FactoryGameSteam-Win64-Shipping.txt`.
- Warnings that appear with a correct game feature mod (also with `ExampleMod`):
  - during the cook and in the game: `LogAssetManager: Warning: Invalid Primary Asset Type FGGameFeatureData:<Mod>: ChangeBundleStateForPrimaryAssets failed to find NameData`,
  - in the game: `LogPluginManager: Warning: Cannot mount plugin localization for '<Mod>' as the plugin isn't explicitly loaded`.
- To follow the log, use the expression `error C[0-9]+|error LNK|fatal error|Result: (Succeeded|Failed)|BUILD (SUCCESSFUL|FAILED)`. First filter out the huge `[Adaptive Build] Excluded from … unity file` lines.

**Packaging output:** `<Project>\Saved\ArchivedPlugins\<Mod>\<Mod>.zip`. Inside is a `Windows\` directory containing:
- `<Mod>.uplugin` and `Resources\Icon128.png`,
- `Binaries\Win64\FactoryGameSteam-<Mod>-Win64-Shipping.dll`, `.pdb` (about 65 MB) and `FactoryGameSteam-Win64-Shipping.modules`,
- `Content\Paks\Windows\<Mod>FactoryGame-Windows.pak`, `.ucas` and `.utoc`.

A mod with assets only has no `Binaries` directory in the zip.

**An interrupted packaging run** leaves the engine's `dotnet.exe` processes running. Kill only those:
```powershell
Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" | ? { $_.ExecutablePath -like '<UE-CSS>\*' } | % { Stop-Process -Id $_.ProcessId -Force }
```

**One copy of the sources.** If you have several copies (working directory, build project, git clone), sync them and check with `diff -rq --strip-trailing-cr`. Before a commit or PR, make sure the repo has exactly the code you built and tested.

## 9. Installing in the game, SMM, backups

**The game must be closed.** A running game locks the DLL, and copying ends with "Permission denied". Check with: `tasklist | findstr FactoryGame`.

**Where to copy `Windows\*` from the zip**
- Game feature mod: to `<Game>\FactoryGame\Mods\GameFeatures\<Mod>\`.
- Regular mod: to `<Game>\FactoryGame\Mods\<Mod>\`.
- The path must match the layout in the project.

**⚠ A mod in the wrong directory** appears in the mod list and its C++ works, but the asset paks do not mount, so nothing works.
- Check the log for the line `LogPakFile: Mounted Pak file '<path>', mount point: '<mount>'`.
- After installation, compare the unpacked build with the directory in the game: `diff -rq`.

**Satisfactory Mod Manager (SMM, ficsit-cli)**
- Mods installed by SMM have a `.smm` marker file. SMM does not touch a manual install without the marker: the mod survived a switch to a profile that did not include it.
- **Consequence: a manually installed mod loads in every SMM profile**, including the "SML only" profile and even when it has `enabled: false` in the profile. A test profile is clean only after you move such mods out of `Mods`.
- **Adding the same mod in SMM overwrites your version** with the release from ficsit.app.
- SMM files:
  - `%APPDATA%\ficsit\profiles.json` and `installations.json`,
  - `%LOCALAPPDATA%\ficsit\registry.db` and `downloadCache`,
  - `<Game>\FactoryGame\Mods\<profile>-lock.json`.

**Backup** of a working, self-built mod:
- Copy the whole mod directory outside the game folder, add a note on how to restore it, and remember the branch with the sources.
- Restore with the game closed. Do not add this mod in SMM.
- A game update can disable the mod through `GameVersion`.

## 10. Running, logs, crashes, measurements

**Game log:** `%LOCALAPPDATA%\FactoryGame\Saved\Logs\FactoryGame.log`.
- Shipping writes Display, Warning and Error lines.
- At every start the old log is renamed to `FactoryGame-backup-<UTC>.log`.
- Timestamps are in **UTC**.
- Line format: `[2026.09.29-17.04.43:468][465]LogX: Display: ...`. The second number is the frame number modulo 1000, so you can compute FPS from the frame difference and the time.
- Many lines with the same frame number spread over seconds mean a hitch. This is how I found a 3-second freeze.

**Useful log lines**
- `LogInit: Engine Version / Net CL / Build Configuration`
- `LogSatisfactoryModLoader: Display: Version check passed … Game Changelist`
- `LogSatisfactoryModLoader: Display: <Mod>: <version>`: the mod loaded.
- `LogNativeHookManager: … Successfully hooked function X`
- `LogLoad: Took N seconds to LoadMap(...)`
- `LogGame: World Serialization (save|load): N seconds`
- `LogPakFile: Mounted Pak file ...`

**Did the mod add errors?** The fastest check is to compare the set of errors with the previous log.
- A game with only SML has constant errors in the log unrelated to mods (DLSS `kFeatureDLSS_G`, `t.MaxFPS`, Niagara, MVVM in `BPW_JoinGame`, `Array_Sort` in SML's `Widget_SessionSettings`).
- Method: `grep -E "Fatal|: Error:"` in both logs, strip the timestamps (`sed -E 's/^\[[^]]*\]\[[^]]*\]//'`), `sort -u` and `diff`. Observed: the set was identical to the one from the `ExampleMod` log.

**Logging in the mod**
- Own category: `DECLARE_LOG_CATEGORY_EXTERN(LogMyMod, Display, All)`.
- One category for several modules: `DECLARE_LOG_CATEGORY_EXTERN` with the export macro of the lowest module (`MYMODCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogMyMod, Log, All);`) in its public header, and `DEFINE_LOG_CATEGORY` in its `.cpp` file. The other modules depend on that module and use the same category.
- Macros that append `__LINE__`.
- Debug logs behind a `constexpr bool`, enabled by a rebuild. One run with full logging produced a 49 MB log.
- Measure the phases of work: `FPlatformTime::Seconds()` at the start and a log like "X done in %.2f s, %d items" at the end.
- A temporary build that logs every event (add, remove, task start and cancel) quickly explains player reports.

**Crash:** the directory `%LOCALAPPDATA%\FactoryGame\Saved\Crashes\UECC-Windows-<id>_0000\` contains:
- `CrashContext.runtime-xml` with the fields `<ErrorMessage>` and `<CallStack>`,
- a copy of the log,
- `UEMinidump.dmp`.

**VRAM of a single process.** Task Manager sums all processes, so it misleads. Count it like this:
```powershell
$p = Get-Process FactoryGameSteam-Win64-Shipping
$c = Get-Counter "\GPU Process Memory(pid_$($p.Id)*)\Dedicated Usage"
($c.CounterSamples | Measure CookedValue -Sum).Sum / 1GB
```
- Leak test: at least 3 save loads and returns to the menu, measuring about 10 s after each load.
- A healthy result: 4.10 → 4.12 → 4.12 GB and 3.65 GB in the menu. A leak, for comparison, grew to 16 GB.

**Game process:** `FactoryGameSteam-Win64-Shipping` (EGS version: `FactoryGameEGS-...`).
