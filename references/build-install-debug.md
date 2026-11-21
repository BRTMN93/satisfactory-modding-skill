# Build, packaging and installation

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own. Running the game, logs, crashes and measurements: `references/debug-logs-crashes.md`.

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

**Linux server build and the four targets.** Packaging for the two dedicated-server targets compiles the Linux server with clang and `-WarningsAsErrors`, so code that builds clean for the Windows client can fail there: `error: loop variable 'Each' creates a copy from type 'const TSubclassOf<UFGConstructDisqualifier>' [-Werror,-Wrange-loop-construct]` for `for (const TSubclassOf<...> Each : Array)`; the fix is `for (const TSubclassOf<...>& Each : Array)`. All four targets are built (`-platform=Win64 -server -serverplatform=Win64+Linux`) before a change counts as releasable; `scripts/package-and-install.ps1 -Target ''` builds only the two client targets (EGS and Steam) and has no server switch, so the four-target build is the direct `RunUAT.bat PackagePlugin ... -server -serverplatform=Win64+Linux -nocompileeditor -installed -merge` call. Evidence: four-target packaging log `Result: Succeeded` only after the `&`, the first attempt failed with the line above. (2026-10-26, game 513885, SML 3.12.0)

**A new C++ plugin in the starter project does not package until the editor target has been built once.** Packaging a freshly added C++ mod (new folder under `Mods/`, its own `.uplugin` and `Build.cs`) stopped in the cook with `Plugin '<Mod>' failed to load because module '<Mod>' could not be found`: the cook runs the editor, which needs the module's editor DLL, and Alpakit/RunUAT only builds the game targets. After `Engine\Build\BatchFiles\Build.bat FactoryEditor Win64 Development -Project=<Project>\FactoryGame.uproject` the same packaging command succeeded and the mod loaded in the game (`LogSatisfactoryModLoader: Display: <Mod>: 1.0.0`). Needed again only when the plugin's module list changes or after a game or SML update. Evidence: the cook error above and the following successful package and load of a test-only helper mod. (2026-11-15, game 517554, SML 3.12.0)

**A source file put back with `Copy-Item` from a backup keeps the backup's old modified time, so the next incremental packaging does not recompile it and the mod ships the binary of the version in between.** Seen: a `.cpp` was replaced for one build by its committed version (new time), packaged, then restored with `Copy-Item <backup> <file>` and committed; the next packaging took 29 s and the game ran the in-between binary (the self-test failed exactly as on the in-between build). After `(Get-Item <file>).LastWriteTime = Get-Date` the same packaging recompiled the module (54 s) and the self-test passed. A restore that sets a new time (`Set-Content`, an editor, a version-control checkout) does not have the problem. Evidence: two <scenario> runs on the same commit, one with the old binary, one after the touch. (2026-11-19, game 520140, SML 3.12.0, UE 5.6.1-CSS, Windows 11)

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

**[?] After switching a game branch or a major update** the game may refuse to start with mods; disable them first (SMM "Mods off", or the `-DisablePlugins` switch described in `references/testing-environment.md`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Satisfactory Mod Manager (SMM, ficsit-cli)**
- Mods installed by SMM have a `.smm` marker file. SMM does not touch a manual install without the marker: the mod survived a switch to a profile that did not include it.
- **Consequence: a manually installed mod loads in every SMM profile**, including the "SML only" profile and even when it has `enabled: false` in the profile. A test profile is clean only after you move such mods out of `Mods`.
- **Adding the same mod in SMM overwrites your version** with the release from ficsit.app.
- SMM can delete a self-built mod: after the user updated SML 3.12.0 to 3.12.1 in SMM (in a profile that did not list `<mod>`), the self-built `<mod>` folder in `FactoryGame\Mods\GameFeatures\` was gone and the next test run had to install the build again. Before a test run after any SMM action, check that the mod folder and its build marker are still there. **[?]** Cause not checked: the folder may still have held an SMM `.smm` marker from an earlier SMM install of the same mod (the build was copied over it), so SMM took it for its own; this would contradict nothing in "Mods installed by SMM have a `.smm` marker file". Copy a self-built mod into a fresh folder, or delete a leftover `.smm` marker. Evidence: test runner reported the mod missing and rebuilt it on the first run after the SML update. (2026-11-21, game 520140, SML 3.12.1, SMM 3.2.0)
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

