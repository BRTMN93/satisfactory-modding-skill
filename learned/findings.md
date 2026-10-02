# Findings inbox

New knowledge and corrections waiting to be folded into the reference files. Format and rules: `references/learning.md`. Add entries under the heading of their target file; create the heading if it is missing.

## New file: railroad.md

Everything in this section was read from game headers (changelist 491125) and asset stubs on 2026-10-01; the game was 502094, SML 3.12.0. None of it has been run in the game yet.

### Where to get data

- **[source]** `AFGRailroadSubsystem` (`FGRailroadSubsystem.h`): `GetAllTrains`, `GetAllTrainStations`. Connected track networks have an identifier that `GetTrackGraphID` returns on a track, a platform and a vehicle.
- **[source]** `AFGTrain` (`FGTrain.h`): `GetTimeTable`, `NewTimeTable`, `SetSelfDrivingEnabled`, `IsPlayerDriven`, `IsDerailed`. Public fields `mConsistData` (vehicles, length, maximum speed, `MaxBrakeDeceleration`) and `mAtcData` (driving supervision data, including the autopilot's current route).
- **[source]** `AFGBuildableRailroadTrack`: `GetLength`, `GetConnection(0/1)`, `GetVehicles`, `GetSignalBlock`. `UFGRailroadTrackConnectionComponent` (`FGRailroadTrackConnectionComponent.h`): connections, switch position, signals, station, `GetSignalBlock`.
- **[source]** `AFGBuildableRailroadStation`: `GetStationIdentifier`, `GetStationOutputConnection`. To walk from a station along its platforms, go through `UFGTrainPlatformConnection` (`GetConnectedTo`, `GetPlatformOwner`).
- **[source]** `AFGBuildableTrainPlatformCargo`: `GetInventory`, `GetIsInLoadMode`, `GetDockingStatus`. The fields `mFreightCargoType` and `mIsFullUnload` are protected, so they need AccessTransformers.
- **[source]** A freight wagon is a single class, `AFGFreightWagon`, with `GetFreightInventory`. The cargo kind is `EFreightCargoType` (none, solid, liquid). There are no separate wagons for liquids.

### Events available without hooks

- **[source]** `AFGTrain`: delegates `mOnDockingStateChanged`, `mOnSelfDrivingErrorChanged`, `mOnTrainStatusChanged`.
- **[source]** `ESelfDrivingLocomotiveError` includes, among others, `SDLE_NoPower`, `SDLE_NoPath`, `SDLE_StationUnreachable`, `SDLE_LongWaitAtSignal`.
- **[source]** `AFGBuildableRailroadSignal`: delegate `mOnAspectChangedDelegate`, `IsPathSignal`. A signal block has `OnBlockChanged`.

### Timetable and docking

- **[source]** `AFGRailroadTimeTable` (`FGRailroadTimeTable.h`): `SetStops` (returns `bool`), `SetCurrentStop`, `AddStop`, `GetStops`. The limit is 100 stops (`MAX_STOPS`).
- **[source]** A stop is an `FTimeTableStop`: a station (`AFGTrainStationIdentifier`) and docking rules.
- **[source]** `FTrainDockingRuleSet` (`FGTrainDockingRules.h`), all fields are saved in the save game:
  - `DockingDefinition`: `ETrainDockingDefinition::TDD_LoadUnloadOnce` (default) or `TDD_FullyLoadUnload`,
  - `DockForDuration` (default 15 s) and `IsDurationAndRule`,
  - `IgnoreFullLoadUnloadIfTransferBlockedByFilters`,
  - `LoadFilterDescriptors` and `UnloadFilterDescriptors`: lists of item classes.
- **[?]** `UFGNoneDescriptor` (`FGNoneDescriptor.h`) as a "nothing" filter: a stop without loading. The behaviour still needs to be tested. Not tested yet.
- **[source]** FicsIt-Networks exposes the same timetable API in Lua, so controlling a train through its timetable has a precedent.

### Routes, signals, blocks

- **[source]** `FRailroadNavigation::FindPathSync(AFGLocomotive*, AFGBuildableRailroadStation*, FRailroadGraphAStarFilter)` (`RailroadNavigation.h`): native A*, synchronous. The target can only be a station, and the locomotive does not turn around.
- **[source]** The private `FindPathSyncInternal(start, end, filter, out_pathPoints)` finds a route between any two track connections. It is a candidate for building custom routes (access via AccessTransformers). Still to be checked.
- **[source]** The edge cost is computed by `FRailroadGraphAStarFilter::GetTraversalCost`.
- **[source]** `AFGTrainScheduler` (`FGTrainScheduler.h`): native block reservations, priorities and starvation protection. The game itself resolves conflicts at junctions.
- **[source]** `FFGRailroadSignalBlock` (`FGRailroadSignalBlock.h`): `GetAspectFor(signal)`, `IsOccupied`, `CreatePathReservation`, `CreateExclusiveReservation`. An ordinary block is exclusive. In a path block several trains run at once if their routes do not cross.
- **[source]** Aspects: `ERailroadSignalAspect` (none, clear, stop, docking).
- **[source]** Driving control: `UFGLocomotiveMovementComponent` has `SetThrottleInput`, `SetAirBrakeInput`, `SetEmergencyBrake`.

### Pitfalls

- **[source]** The name `FTrackGraph` is taken by a game struct (`FGRailroadSubsystem.h`). Custom track graph types must use a different name or a prefix.
- **[source]** Class names suggested by a chatbot, `AFGBuildableRailroadTrackConnection` and `AFGTrainHalt`, do not exist. The right ones are `UFGRailroadTrackConnectionComponent`, `AFGBuildableRailroadStation` and `AFGTrainStationIdentifier`. Always verify game class names in the headers.
- **[?]** While docking, the game pauses the platform's belts and pipes. This is suggested by the existence of the mod Uninterrupted Train Belts/Pipes, which turns that off. Still to be measured.

## references/rendering-ui.md

Game railway widgets: variable names extracted from `.uasset` stubs in the starter project, using the method described in the skill.

- **[source]** `Content/FactoryGame/Buildable/Factory/Train/Signal/Widget_RailroadSignal`: the signal's interaction window (a child of `FGInteractWidget`). Variables: `mSignal`, `mTopSignal`, `mBottomSignal`, `mCurrentStateLabel`, `mDescriptionText`. So signals have their own menu that can be extended. (2026-10-01, headers 491125, game 502094, SML 3.12.0)
- **[source]** `Content/FactoryGame/Buildable/Factory/Train/Station/Widget_TrainStationNew`: the railway window with tabs. Variables: `mTabs` (`Widget_SlidingTabs`), `mTrainList`, `mStationList`, `mLocomotiveMenuContainer`. (2026-10-01, headers 491125, game 502094, SML 3.12.0)
- **[source]** `Content/FactoryGame/Buildable/Vehicle/Train/Locomotive/UI/Widget_Locomotive_Menu`: the train window with the timetable editor. It also has `mTabs`. (2026-10-01, headers 491125, game 502094, SML 3.12.0)

## references/sml-api.md

- **[source]** Slider in a mod's settings: the classes `UCP_Integer` and `UCP_Float` from `Configuration/Properties/WidgetExtension/`. They have `WidgetType` (text field, slider `CPI_Slider` / `CPF_Slider`, spin box, and for integers also a list from an enum) and `MinValue` and `MaxValue`. They inherit from `UConfigPropertyInteger` and `UConfigPropertyFloat`, so reading the value from C++ does not change. (2026-10-01, game 502094, SML 3.12.0)
- **Root modules must be Blueprint assets, because SML looks for them only in the asset registry.** `PluginModuleLoader.cpp:39-41` calls `FindBlueprintAssetsByTag(..., "bRootModule", {"True"})`. A C++ class with `bRootModule = true` would not be found at all, so the skill's pattern (a C++ class without the flag plus a Blueprint child with the flag) is the only way, not just good practice. Blueprint roots work: in the game the instance module logged `CONSTRUCTION`, `INITIALIZATION` and `POST_INITIALIZATION`. (2026-10-02, game 502094, SML 3.12.0)
- **A validation error on the first save of a module Blueprint is normal.** Saving before ticking **Root Module** gives this in the editor log: `AssetCheck: Error: [AssetLog] …Root….uasset: At least one module of this type was found in this mod, but none were marked as root. Fix by marking at least one as root.` After ticking the flag and saving again, validation passes without an error. The flag is in **Class Defaults**, in the **Details** panel, named **Root Module**. (2026-10-02, game 502094, SML 3.12.0)
- **[?]** A world module's `ModSubsystems` can be set in the constructor of the C++ class (`ModSubsystems.Add(AMySubsystem::StaticClass())`), and the Blueprint child inherits that value. Then only **Root Module** needs ticking in the root Blueprint. It compiles and packages. Whether the subsystem is actually created in the world still needs to be checked by loading a save and logging from the subsystem. Not tested yet. (2026-10-02, game 502094, SML 3.12.0)

## references/testing-publishing.md

- Searching for mods on ficsit.app through the API. Several queries at once are separated by aliases (`a:`, `b:`):
  ```bash
  curl -s https://api.ficsit.app/v2/query -H "Content-Type: application/json" \
    -d '{"query":"{ a: getMods(filter: {search: \"train\", limit: 40, order_by: downloads, order: desc}) { mods { name mod_reference short_description downloads } } }"}'
  ```
  A `getModByReference` that returns `null` means the mod reference is free. (2026-10-01, game 502094, SML 3.12.0)
- **Before designing a mod, search ficsit.app through the API, not with a web search engine.** The web search engine did not find any of the existing railway mods, including a mod with 60 thousand downloads. The API found them at once. Search with several words from the domain (for example: train, station, logistic, dispatch). (2026-10-01, game 502094, SML 3.12.0)
- **[source]** Starting the game straight into a save, according to docs.ficsit.app (Development → Testing):
  `-ini:Engine:[/Script/EngineSettings.GameMapsSettings]:GameDefaultMap=/Game/FactoryGame/Map/GameLevel01/Persistent_Level.Persistent_Level,[/Script/EngineSettings.GameMapsSettings]:LocalMapOptions=?skipOnboarding?listen?loadgame=<save name without path and extension>`.
  The documentation also gives a ready-made PowerShell script for launching the game (with, among others, the parameters `-loadLatestSave` and `-multiplayer`) and the parameters `-EpicPortal`, `-NoSteamClient`, `-log`, `-NewConsole`, `-nosplash`, `-windowed`, `-WaitForDebugger`. The syntax comes from a summary of the page, so it must be confirmed against the source. Not tested yet. (2026-10-01, game 502094, SML 3.12.0)
- **[source]** Testing with two clients locally: the host sets the session type to `IP`, the client types `open 127.0.0.1` in the console. Dedicated server locally: `FactoryServer.exe -log -EpicPortal -NoSteamClient`. Source as above. (2026-10-01, game 502094, SML 3.12.0)

## references/patterns-and-pitfalls.md

- **The game's `.cpp` files in the starter project are stubs with empty function bodies** (for example `void AFGTrain::TickSelfDriving(float dt){ }`). From the headers you can read what exists, but not how it works. Every assumption about the behaviour of native code needs a short experiment in the packaged game before code is built on it. (2026-10-01, headers 491125, game 502094, SML 3.12.0)
- **The starter project's headers can be older than the installed game, and that has consequences.** Observed: the local `Source/FactoryGame/currentVersion.txt` said 491125, while the game is 502094. Comparison with the current SML repository showed:
  - The `master` branch of the `satisfactorymodding/SatisfactoryModLoader` repository has the 502094 headers since commit `d2162c9` of 2026-08-12 ("Update headers to CL502094", 76 files). SML stayed at version 3.12.0 through this, and its public headers did not change. So the SML version alone does not tell whether the game headers are up to date.
  - 39 game headers changed. In `AFGBuildable`, 6 virtual functions were removed (the old set of build effects), 5 new ones were added, and 3 changed position. Derived classes, including the signal and the switch, now override `OnLegacyBuildEffectFinished` instead of `OnBuildEffectActorFinished`.
  - **[source]** Conclusion: a mod built on old headers has the wrong virtual function table layout for all buildables. Calling a virtual function, hooking a virtual function or a custom class derived from a buildable will land in the wrong place. Non-virtual functions are linked by name, so a mod that uses only those may keep working and notice nothing.
  - How to check in two minutes: compare `currentVersion.txt` with the game's changelist (`<Game>\Engine\Binaries\Win64\*.version`). The version in the repository is shown by `gh api "repos/satisfactorymodding/SatisfactoryModLoader/contents/Source/FactoryGame/currentVersion.txt" --jq .content | base64 -d`. The headers themselves can be fetched with a partial clone (`git clone --depth 1 --filter=blob:none --sparse`, then `git sparse-checkout set Source/FactoryGame/Public`) and compared with `diff -rq --strip-trailing-cr`.
  - This partly answers the skill's open question "which branch to take the starter project from": `master` follows the current game, and `currentVersion.txt` says which changelist the headers are for.

  (2026-10-01, headers 491125, game 502094, SML 3.12.0)
- **The folder the chat works in does not have to be the project that is built.** Observed: sessions worked on a copy of the sources on the desktop (1 GB, without `Intermediate`, `Binaries` and Wwise), while building happened in a second copy on another drive. Before you record environment paths, check where `Binaries`, `Intermediate` and `Saved\ArchivedPlugins` are. The simplest setup is one copy that you work in. (2026-10-01, game 502094, SML 3.12.0)
- **Before testing, check which mods are in the game installation.** Mods that interfere with the same area distort the results of experiments. Observed: the game had two mods that replace train routes and timetables. The list is given by the directories `<Game>\FactoryGame\Mods` and `<Game>\FactoryGame\Mods\GameFeatures`. Test in a separate SMM profile with SML only. (2026-10-01, game 502094, SML 3.12.0)

## references/setup.md

- **Double-clicking `FactoryGame.uproject` may not open the CSS editor.** `.uproject` files are opened by `UnrealVersionSelector.exe` from the Epic Games Launcher, which answers "No Unreal Engine installations found. Would you like to locate one manually?", even though the engine is registered in `HKCU\Software\Epic Games\Unreal Engine\Builds` as `5.6.1-CSS`. The cause is unknown. Launching directly works: `<UE-CSS>\Engine\Binaries\Win64\UnrealEditor.exe "<Project>\FactoryGame.uproject"`. (2026-10-02, game 502094, SML 3.12.0)
- **In UE 5.6 the bottom file panel is called Content Drawer, not Content Browser.** A mod's content is in it under `Plugins` → `<Mod> Content`. If `Plugins` is not visible, enable **Settings** → **Show Plugin Content**. Instructions for the user should use the name shown in the editor. (2026-10-02, game 502094, SML 3.12.0)
- **The editor's cache (Zen DDC) grows on drive C:, but it can be moved.** The data is in `%LOCALAPPDATA%\UnrealEngine\Common\Zen\Data` (`BaseEngine.ini`, `[Zen.AutoLaunch] DataPath=%ENGINEVERSIONAGNOSTICINSTALLEDUSERDIR%Zen/Data`). After the first editor start and one packaging it took 0.5 GB. Zen cleans it up by itself only when less than 2 GB is left on the drive (`--gc-low-diskspace-threshold`).
  - Verified method: with the editor closed, copy the folder to another drive, compare the file count and the total size, delete the original and create a directory junction in its place (`New-Item -ItemType Junction`). The same was done with `%USERPROFILE%\.nuget\packages` (1.8 GB of .NET packages, used by UBT among others).
  - The junction works at once for every process, and the data moves with the folder, so shaders are not compiled again.
  - **[source]** The engine-settings way is the environment variable `UE-LocalDataCachePath` (`LocalDataCachePathEnvOverride` in `[Zen.AutoLaunch]`). It works only in processes started after it is set, and it does not move existing data.

  (2026-10-02, game 502094, SML 3.12.0)

## references/mod-structure.md

- **A game feature mod with several C++ modules packages and loads with no change to the procedure.** Observed: a mod with five `Runtime` modules in phase `Default`, listed in `Modules` in the `.uplugin`. The skill's packaging script worked unchanged (4 min 09 s, game already compiled earlier). The zip has a separate DLL and PDB for each module (`FactoryGameSteam-<Module>-Win64-Shipping.dll`) and one shared `FactoryGameSteam-Win64-Shipping.modules`. In the game the modules load in the order of the `.uplugin`, all in the same millisecond, before `Version check passed` and before the SML mod list. (2026-10-02, game 502094, SML 3.12.0)
- **One log category for several modules:** `DECLARE_LOG_CATEGORY_EXTERN` with the export macro of the lowest module (`MYMODCORE_API DECLARE_LOG_CATEGORY_EXTERN(LogMyMod, Log, All);`) in its public header, and `DEFINE_LOG_CATEGORY` in its `.cpp` file. The other modules depend on that module and use the same category. (2026-10-02, game 502094, SML 3.12.0)
- **The compiler enforces the boundary between modules.** A module that does not have `FactoryGame` in its `Build.cs` dependencies cannot include a game header: `fatal error C1083: Cannot open include file: 'FGTrain.h': No such file or directory`. This can be used to enforce that pure logic does not depend on game classes. Such a module needs only the dependencies `Core` and `CoreUObject`. (2026-10-02, game 502094, SML 3.12.0)

## references/build-install-debug.md

- **Warnings that appear with a correct game feature mod** (also with `ExampleMod`):
  - during the cook and in the game: `LogAssetManager: Warning: Invalid Primary Asset Type FGGameFeatureData:<Mod>: ChangeBundleStateForPrimaryAssets failed to find NameData`,
  - in the game: `LogPluginManager: Warning: Cannot mount plugin localization for '<Mod>' as the plugin isn't explicitly loaded`.

  (2026-10-02, game 502094, SML 3.12.0)
- **The fastest way to check whether a mod added errors to the log is to compare the set of errors with the previous log.** A game with only SML has constant errors in the log unrelated to mods (DLSS `kFeatureDLSS_G`, `t.MaxFPS`, Niagara, MVVM in `BPW_JoinGame`, `Array_Sort` in SML's `Widget_SessionSettings`). Method: `grep -E "Fatal|: Error:"` in both logs, strip the timestamps (`sed -E 's/^\[[^]]*\]\[[^]]*\]//'`), `sort -u` and `diff`. Observed: the set was identical to the one from the `ExampleMod` log. (2026-10-02, game 502094, SML 3.12.0)

## Corrections

- **`SKILL.md`, procedure "New mod": make "Alpakit → Create Mod" more precise.** Alpakit adds two icons to the editor toolbar, after the Play group and next to **Platforms**: **Alpakit Dev** (an alpaca) and **Alpakit Release** (a rocket). The same windows and **Alpakit Log** are in the **File** menu, in the project section. The wizard is the **Create Mod** button in the **Alpakit Dev** window. Templates: Blueprint Only, C++ & Blueprint, Blueprint Library (Advanced), C++ & Blueprint Library (Advanced). The first two create a game feature mod. The wizard warns that the plugin name (the mod reference) cannot be changed later. Source: `Mods/Alpakit/Source/Alpakit/Private/Alpakit.cpp`, `AlpakitDevWidget.cpp`, `Mods/Alpakit/Templates/templates.json` and an editor screenshot. (2026-10-02, game 502094, SML 3.12.0)
