# Build, packaging, installation, logs and diagnostics

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Build and packaging

Alpakit in the editor is only a wrapper around RunUAT `PackagePlugin`. Calling it directly is faster:
```powershell
& "<UE-CSS>\Engine\Build\BatchFiles\RunUAT.bat" -ScriptsForProject="<Project>\FactoryGame.uproject" PackagePlugin `
  -project="<Project>\FactoryGame.uproject" -clientconfig=Shipping -serverconfig=Shipping -utf8output `
  -DLCName=<Mod> -build -platform=Win64 -nocompileeditor -installed -merge -Target=FactoryGameSteam *> package.log
```

**Flags**
- Without `-Target` it builds both targets, `FactoryGameEGS` and `FactoryGameSteam`. `-Target=FactoryGameSteam` halves local test time.
- Servers: `-server -serverplatform=Win64+Linux`. Linux needs the toolchain from `references/setup.md`, "Linux toolchain".

**Checks in the Shipping build**
- **[source]** Mod code is compiled with checks active in the Shipping build. The starter project's `Source/FactoryShared.Target.cs` sets `bUseChecksInShipping = UseChecksInShippingOverride` (`:74`), which is `true` by default (`:12`, `// MODDING EDIT: we want checks in shipping by default`), and the packaging log says `Building with command line overrides: ChecksInShipping: True (default: false); LinkType: Modular`. The setting becomes `USE_CHECKS_IN_SHIPPING=1` (engine `UEBuildTarget.cs:5814`) and `DO_CHECK` (`Build.h:305`); ensures follow it (`Build.h:211`). So in a mod both `check()` and `ensure()` are live in the Shipping build, and a failed `check()` stops the packaged game. docs.ficsit.app (Cpp debugging) advises `fgcheck()` because it is on in Shipping (`AssertionMacros.h:377`, always on); that advice is about the game's own code, not about mod code, which is built with the starter project's target rules. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[?]** Stale editor DLLs: the RunUAT line above passes `-nocompileeditor`, and Alpakit does the same when the editor is running (`AlpakitProfile.cpp:86`), so the cook runs against the editor DLLs that were built last. Observed: a mod's `UnrealEditor-<Mod>*.dll` files were 11 days older than its Shipping DLLs. The risk is for Blueprint assets derived from a `UCLASS` or `UPROPERTY` that was renamed or changed in type; docs.ficsit.app says to rebuild the Development Editor target (`FactoryEditor`) after a change of class structure. No failure was seen. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Times**
- First Shipping packaging: 21–47 min. A mod with assets only in a fresh project: 21 min (game compile 297 actions in 700 s, cook 497 s, UnrealPak a few seconds).
- Later runs, when only the mod changes: 1.3–5 min. Group your changes and compile once.
- Measured with 16 GB RAM, a game feature mod with five small C++ modules, Steam target only: 49–215 s after a change in one `.cpp` file, 24–44 s with nothing changed.

**How to read the result**
- Success: `Result: Succeeded`, `BUILD SUCCESSFUL`, `AutomationTool exiting with ExitCode=0`.
- Compile error: `Result: Failed (OtherCompilationError)`, `BUILD FAILED`, ExitCode=6.
- Error details: `%APPDATA%\Unreal Engine\AutomationTool\Logs\<engine path>\UBA-FactoryGameSteam-Win64-Shipping.txt`.
- `DirectoryNotFoundException: Could not find a part of the path` at the start of packaging: docs.ficsit.app (ImportingAnotherMod) blames a folder name that differs from the mod reference. In the engine, UAT resolves `-DLCName` by plugin name among the plugins it found and falls back to `Plugins/<name>/<name>.uplugin` (`AutomationUtils/ProjectParams.cs:757-765`) **[source]**. So the cause is that UAT did not find a plugin with that name: a wrong `.uplugin` file name, a `.uplugin.disabled`, or a mod outside `Mods/`. Whether a differing folder name alone causes it was not tested **[?]**. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- Warnings that appear with a correct game feature mod (also with `ExampleMod`):
  - during the cook and in the game: `LogAssetManager: Warning: Invalid Primary Asset Type FGGameFeatureData:<Mod>: ChangeBundleStateForPrimaryAssets failed to find NameData`,
  - in the game: `LogPluginManager: Warning: Cannot mount plugin localization for '<Mod>' as the plugin isn't explicitly loaded`.
- To follow the log, use the expression `error C[0-9]+|error LNK|fatal error|Result: (Succeeded|Failed)|BUILD (SUCCESSFUL|FAILED)`. First filter out the huge `[Adaptive Build] Excluded from … unity file` lines.

**Packaging output:** `<Project>\Saved\ArchivedPlugins\<Mod>\<Mod>.zip`. Inside is a `Windows\` directory containing:
- `<Mod>.uplugin` and `Resources\Icon128.png`,
- `Binaries\Win64\FactoryGameSteam-<Mod>-Win64-Shipping.dll`, `.pdb` (about 65 MB) and `FactoryGameSteam-Win64-Shipping.modules`,
- `Content\Paks\Windows\<Mod>FactoryGame-Windows.pak`, `.ucas` and `.utoc`.

A mod with assets only has no `Binaries` directory in the zip.

**Release packaging (Alpakit Release) [source].** The release profile is the same `PackagePlugin` call with `-clientconfig=Shipping -serverconfig=Shipping -utf8output -DLCName=<Mod> [-build, if the mod has modules] -platform=Win64 -server -serverplatform=Win64+Linux -nocompileeditor -installed -merge` and **no `-Target`** (`AlpakitProfile.cpp:68-113`, `Alpakit.cpp:224-236`, `PackagePlugin.cs:126-158,173-213`). The targets come from `Config/Alpakit.ini` (`references/mod-structure.md`).
- Without `-Target` the `Windows\` folder holds the files for both clients: `FactoryGameSteam-...` and `FactoryGameEGS-...` DLLs and `.modules` files.
- Output in `<Project>\Saved\ArchivedPlugins\<Mod>\`: one zip per target, `<Mod>-<Platform>.zip` with the files at the zip root, and the merged `<Mod>.zip` with `Windows\`, `WindowsServer\` and `LinuxServer\`. Upload the merged one, the largest. Seen on disk in a packaged zip. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**An interrupted packaging run** leaves the engine's `dotnet.exe` processes running. Kill only those:
```powershell
Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" | ? { $_.ExecutablePath -like '<UE-CSS>\*' } | % { Stop-Process -Id $_.ProcessId -Force }
```

**One copy of the sources.** If you have several copies (working directory, build project, git clone), sync them and check with `diff -rq --strip-trailing-cr`. Before a commit or PR, make sure the repo has exactly the code you built and tested.

**Packaging for the Windows dedicated server.** `RunUAT.bat PackagePlugin -project=<FactoryGame.uproject> -clientconfig=Shipping -serverconfig=Shipping -utf8output -DLCName=<Mod> -build -server -serverplatform=Win64 -noclient -nocompileeditor -installed -merge -Target=FactoryServer`. The zip `Saved\ArchivedPlugins\<Mod>\<Mod>.zip` gets a `WindowsServer/` folder; copy its contents into `<server>\FactoryGame\Mods\SML` for SML and `<server>\FactoryGame\Mods\GameFeatures\<Mod>` for a game feature mod. `-merge` overwrites the same `<Mod>.zip` the client packaging wrote, so the client package has to be installed (or copied away) before the server build. **[?]** SMM 3.0 and later and ficsit-cli can manage a dedicated server install (local, SFTP/FTP or SMB) for mods published on ficsit.app (docs only). Seen on disk: `%APPDATA%\ficsit\installations.json` lists the server folder, and the server's `Mods` carry `.smm` markers and a `<profile>-lock.json`. A self-built mod is not on ficsit.app, so it still has to be copied by hand (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app; `.smm` and `installations.json` seen on disk). SML is packaged the same way from the same starter project (SML server package about 26 s; the first server build of a starter about 6 min, later ones 1–2 min). Evidence: server log `LogSatisfactoryModLoader: Display: <Mod>: <version>` and `Version check passed ... 513885`. (2026-10-21, game 513885, SML 3.12.0)

## Installing in the game, SMM, backups

**The game must be closed.** A running game locks the DLL, and copying ends with "Permission denied". Check with: `tasklist | findstr FactoryGame`.

**Where to copy `Windows\*` from the zip**
- Game feature mod: to `<Game>\FactoryGame\Mods\GameFeatures\<Mod>\`.
- Regular mod: to `<Game>\FactoryGame\Mods\<Mod>\`.
- The path must match the layout in the project.

**⚠ A mod in the wrong directory** appears in the mod list and its C++ works, but the asset paks do not mount, so nothing works.
- Check the log for the line `LogPakFile: Mounted Pak file '<path>', mount point: '<mount>'`.
- After installation, compare the unpacked build with the directory in the game: `diff -rq`.

**The same mod in two folders.** When a mod lies under both `Mods\<Mod>` and `Mods\GameFeatures\<Mod>`, the engine uses the first one it found (`PluginManager.cpp:1249`), and that is the top-level `Mods\<Mod>` although "GameFeatures" sorts first. Tested with `Mods\<Mod>` at 1.0.1 and `Mods\GameFeatures\<Mod>` at 1.0.0: SML and the mod reported 1.0.1. The engine warns at discovery `LogPluginManager: Warning: The same version (v1) of plugin '<Mod>' exists at '../../../FactoryGame/Mods/<Mod>/<Mod>.uplugin' and '.../Mods/GameFeatures/<Mod>/<Mod>.uplugin' - second location will be ignored.` and then `A version of the '<Mod>' plugin has already been enabled (<path>); prioritizing that over the newly discovered version (<path2>)`; the warning compares the integer `Version` (both 1), not `SemVersion`. A stale copy in `Mods\<Mod>` therefore hides every new install in `GameFeatures`: delete the old install folder. (2026-10-24, game 513885, SML 3.12.0)

**Alpakit "Copy to game" and the PackagePlugin switches**
- Alpakit's copy deletes `<Game>\FactoryGame\Mods[\GameFeatures]\<Mod>` completely and then copies the staged mod (`PackagePlugin.cs:165-171`), and it needs `<Game>\FactoryGame` to exist (`:92-97`). Files put by hand into the installed mod folder are lost. Tested with `PackagePlugin -CopyToGameDirectory_Windows=<Game>`: a marker file left in the installed `Mods\GameFeatures\<Mod>` before packaging was gone afterwards and the folder held only the new files (`.uplugin`, `Binaries`, `Content\Paks`). **[source]** for the rest of this block.
- The same from RunUAT: `-CopyToGameDirectory_Windows=<GameDir>` (copies by itself to `Mods\GameFeatures\<Mod>` or `Mods\<Mod>`; without `-merge` it builds only the target whose exe lies in `<GameDir>`, `PackagePlugin.cs:52-66,139-153`). `-LaunchGame_Windows=Steam|SteamDS|EpicEA|EpicExp|EpicDS|EpicDSExp|Custom` starts the game, with `-CustomLaunchPath_Windows=` and `-CustomLaunchArgs_Windows=` for `Custom`. The `Steam` type is `steam://rungameid/526870`, which carries no arguments, so only `Custom` can pass `-ini:...` or other switches (`LaunchGame.cs`).
- `scripts/package-and-install.ps1` copies with `Copy-Item -Force` into the existing folder and never deletes, so a file removed from the mod stays installed (`scripts/package-and-install.ps1`, line 50). Clear the folder first when files were removed. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Load errors for the wrong build or a missing dependency [source]** (strings from the engine, `PluginManager.cpp`; the EGS case was not reproduced)
- Alpakit picks the single client target from the exe in the game folder (`FactoryGameSteam.exe` or `FactoryGameEGS.exe`) when it does not merge (`PackagePlugin.cs:139-154`). A Steam-only build in an EGS game fails with `Plugin '<Mod>' failed to load because module '<M>' could not be found` (`:2708`).
- `... does not appear to be compatible with the current version of the engine` (`:2712`).
- `This project requires the '<Mod>' plugin, which has a missing dependency on the 'SML' plugin` (`:2606`): SML is not installed. (2026-10-24, game 513885, SML 3.12.0)

**[?] After switching a game branch or a major update** the game may refuse to start with mods; disable them first (SMM "Mods off", or the `-DisablePlugins` switch described in `references/testing.md`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Satisfactory Mod Manager (SMM, ficsit-cli)**
- Mods installed by SMM have a `.smm` marker file. SMM does not touch a manual install without the marker: the mod survived a switch to a profile that did not include it.
- **Consequence: a manually installed mod loads in every SMM profile**, including the "SML only" profile and even when it has `enabled: false` in the profile. A test profile is clean only after you move such mods out of `Mods`.
- **Adding the same mod in SMM overwrites your version** with the release from ficsit.app.
- SMM files:
  - `%APPDATA%\ficsit\profiles.json` and `installations.json`,
  - `%LOCALAPPDATA%\ficsit\registry.db` and `downloadCache`,
  - `<Game>\FactoryGame\Mods\<profile>-lock.json`.
  - Seen on disk (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app): `%APPDATA%\SatisfactoryModManager\settings.json`; the SMM log `%LOCALAPPDATA%\SatisfactoryModManager\logs\SatisfactoryModManager.log`; `%LOCALAPPDATA%\ficsit\downloadCache\<ModRef>_<ver>_<Target>.zip`, one archive per target (`Windows`, `WindowsServer`, `LinuxServer`), where a mod zip can also be placed by hand; `installations.json`, which lists dedicated servers too. `<profile>-lock.json` has a `targets` map with hash and link per mod.
  - **[?]** From the docs only: a window that opened off-screen is fixed with `windowPosition` x and y set to 0 in `settings.json`; the cache folder can be changed in SMM's settings; SMM's "generate debug info" makes a zip with the game, SML and SMM logs, the usual attachment for a help request.

**Backup** of a working, self-built mod:
- Copy the whole mod directory outside the game folder, add a note on how to restore it, and remember the branch with the sources.
- Restore with the game closed. Do not add this mod in SMM.
- A game update can disable the mod through `GameVersion`.

## Running, logs, crashes, measurements

**Game log:** `%LOCALAPPDATA%\FactoryGame\Saved\Logs\FactoryGame.log`.
- Shipping writes Display, Warning and Error lines.
- At every start the old log is renamed to `FactoryGame-backup-<UTC>.log`.
- Timestamps are in **UTC**.
  - The first line, `Log file open, <date> <time>`, is in **local** time, while the line stamps and the backup name are UTC, and the backup is named after the UTC time of the *new* start that renamed it. A run's log therefore cannot be matched to a start time without the time zone; match it by its first line and a line number. Evidence: `Log file open, 10/06/26 19:01:03` above line stamps of 17.01 UTC (UTC+2); a log first opened at 20:21:45 local became `FactoryGame-backup-2026.10.06-18.21.45.log`. (2026-10-06, game 502094, SML 3.12.0)
- Line format: `[2026.09.29-17.04.43:468][465]LogX: Display: ...`. The second number is the frame number modulo 1000, so you can compute FPS from the frame difference and the time.
- Many lines with the same frame number spread over seconds mean a hitch. A 3-second freeze was found this way.

**Useful log lines**
- `LogInit: Engine Version / Net CL / Build Configuration`
- `LogSatisfactoryModLoader: Display: Version check passed … Game Changelist`
- `LogSatisfactoryModLoader: Display: <Mod>: <version>`: the mod loaded.
- `LogNativeHookManager: … Successfully hooked function X`
- `LogLoad: Took N seconds to LoadMap(...)`
- `LogGame: World Serialization (save|load): N seconds`
- `LogPakFile: Mounted Pak file ...`

**SML log categories for diagnosis [source]** (all defined with `DEFINE_LOG_CATEGORY*` in SML): `LogBlueprintHookManager` and `LogBlueprintHookingCodeGen` (a Blueprint hook that does not attach, and the bytecode), `LogWidgetBlueprintHookManager`, `LogContentRegistry` (errors about a frozen registry), `LogSubsystemManager`, `LogConfigManager`, `LogChatCommand`, `LogSessionSettingsRegistry`, `LogGameMapRegistry`, `LogModNetworkHandler`. `scripts/watch-log.ps1` can match these categories. (2026-10-24, game 513885, SML 3.12.0)

**Did the mod add errors?** The fastest check is to compare the set of errors with the previous log.
- A game with only SML has constant errors in the log unrelated to mods (DLSS `kFeatureDLSS_G`, `t.MaxFPS`, Niagara, MVVM in `BPW_JoinGame`, `Array_Sort` in SML's `Widget_SessionSettings`).
- Loading a freshly created save (new game, only SML installed) also logs several `LogSave: Error: Object Reference '<id>::Persistent_Level:PersistentLevel.BP_CreatureSpawner<N>' is contained inside of the World Partition Cell ...` lines, and the same for `BP_Spline<N>`. Exclude them when comparing error sets.
- Method: `grep -E "Fatal|: Error:"` in both logs, strip the timestamps (`sed -E 's/^\[[^]]*\]\[[^]]*\]//'`), `sort -u` and `diff`. Observed: the set was identical to the one from the `ExampleMod` log.

**Logging in the mod**
- Own category: `DECLARE_LOG_CATEGORY_EXTERN(LogMyMod, Display, All)`.
- Keep the compile-time verbosity `All` for a category named `Log<ModRef>`. SML creates `Log<PluginName>` for the Blueprint log nodes with compile-time `All` (`BlueprintLoggingLibrary.cpp:16-21,45-50`); a C++ category of the same name with another compile-time verbosity (tested: `DECLARE_LOG_CATEGORY_EXTERN(Log<ModRef>, Log, Log)`) in a mod that also uses Blueprint log nodes kills the game at the first call of an SML log node from a Blueprint of that plugin, not at load, because SML creates its dynamic category lazily: `LogSatisfactoryModLoader: Registering dynamic Blueprint logging category Log<ModRef> with default verbosity Verbose`, then `Fatal error: [...LogSuppressionInterface.cpp] [Line: 460] Log suppression category Log<ModRef> is defined multiple times with different compile time verbosity.`, also in `CrashContext.runtime-xml` (`LogSuppressionInterface.cpp:455-459`). The `All` variant was not run (it is what the templates use). docs.ficsit.app says the same. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- One category for several modules: `DECLARE_LOG_CATEGORY_EXTERN` with the export macro of the lowest module (`MYMODCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogMyMod, Log, All);`) in its public header, and `DEFINE_LOG_CATEGORY` in its `.cpp` file. The other modules depend on that module and use the same category.
- Macros that append `__LINE__`.
- Debug logs behind a `constexpr bool`, enabled by a rebuild. One run with full logging produced a 49 MB log.
- Measure the phases of work: `FPlatformTime::Seconds()` at the start and a log like "X done in %.2f s, %d items" at the end.
- A temporary build that logs every event (add, remove, task start and cancel) quickly explains player reports.

**Editor and packaging logs.** The editor writes `<Project>\Saved\Logs\FactoryGame.log` (plus `UnrealPak-backup-*.log`; seen on disk), packaging `%APPDATA%\Unreal Engine\AutomationTool\Logs\` (see "Build and packaging"). docs.ficsit.app also names `%LOCALAPPDATA%\UnrealEngine\<ver>\Saved\Logs`, which did not exist here **[?]**. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Attaching a debugger**
- Process: `FactoryGameSteam-Win64-Shipping.exe` (EGS: `FactoryGameEGS-...`). docs.ficsit.app (Cpp debugging) says `FactoryGame-Win64-Shipping.exe`; the install has only `<Game>\Engine\Binaries\Win64\FactoryGameSteam-Win64-Shipping.exe` and its `.pdb` (26 MB), the game's pdbs are in `FactoryGame\Binaries\Win64`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[source]** `-WaitForDebugger` attaches late, in SML's init (`SatisfactoryModLoader.cpp:150-160`). The engine skips its structured-exception guard only when `-NoExceptionHandler` is given or a debugger is present when `WinMain` starts (`LaunchWindows.cpp:240-269`); after a late attach the guard stays on and SML logs a warning (`SatisfactoryModLoader.cpp:177`), so an access violation does not reach the debugger. Pass both `-WaitForDebugger` and `-NoExceptionHandler`. Side effect (tested): the engine's crash reporter is bypassed, so that run leaves no `UECC-Windows-*\CrashContext.runtime-xml` (a null write without the flag did write one, `game process exit code: 0x00000003`). The game's Sentry SDK still catches the exception with the flag: it logs the error and a symbolised call stack with mod frames into `FactoryGame.log` under `LogSentrySdk` (`LogSentrySdk: Error: Unhandled Exception: EXCEPTION_ACCESS_VIOLATION writing address 0x0000000000000000`, `LogSentrySdk: Error: [Callstack] ...`), logs `sending envelope`, hands control to crashpad and writes a minidump to `%LOCALAPPDATA%\FactoryGame\.sentry-native\reports\<id>.dmp` (the log and a screenshot under `.sentry-native\attachments\<id>\`); the process ends with `0xC0000005`, and no WER dump went to `%LOCALAPPDATA%\CrashDumps`. So `-NoExceptionHandler` does not leave the crash to WER or a debugger alone, and the Sentry minidump is the dump to open. The files were gone after the run (crashpad removes them once sent, so the report was most likely uploaded) **[?]**: whether the envelope reaches the Sentry server for a modded game was not checked.
- **[source]** Ensures and errors break into an attached debugger (`SatisfactoryModLoader.cpp:164-173`, `OnHandleSystemEnsure/Error` calls `DebugBreak`). An `ensure()` in mod code is live in Shipping (see "Checks in the Shipping build"), so it stops the debugger.
- **[?]** From the docs, Visual Studio: after the first attach use "Reattach to Process"; untick Debug > Options > Debugging > General > "Require source files to exactly match"; a Function Breakpoint `ClassName::FunctionName` works on vanilla functions through the shipped pdbs, "most of the time". (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

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
- A test run that ends with `RequestExit` can crash in SML's config flush at exit: `Fatal error … EXCEPTION_ACCESS_VIOLATION reading address 0x40`, call stack `UModLoadingLibrary::LoadMetadataForPlugin` ← `UConfigManager::SaveConfigurationInternal` ← `UConfigManager::FlushPendingSaves` ← `FEngineLoop::AppPreExit`. It came after the scenario's `RESULT` line and the save file was written, so the run's result stands; the test script reads the result from the log, not from the exit code. Seen once with an older build of the same mod in 21 runs that day, 20 of them exiting cleanly. The cause: a config value changed before SML's 0.2 s save timer has fired is still pending at exit and the exit flush runs after the mod list is gone; in a 2026-10-24 test (game 513885) the same exit died silently instead, with no crash report, and exits 0.5 s or more after the change were clean (`references/sml-config-networking.md`, "Config"). (2026-10-11, game 502094, SML 3.12.0)

**Dedicated server paths on Windows:** log `<server>\FactoryGame\Saved\Logs\FactoryGame.log`; saves `%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\server` (the same user profile as the game, folder `server`); server settings `ServerSettings.<port>.sav` in `SaveGames`. At start the server loads the newest save of its folder by itself, so a test that uploads its own save moves the old ones aside first, or the run starts in the wrong world. Evidence: a test started in a previous run's world until the old saves were moved. (2026-10-21, game 513885)
