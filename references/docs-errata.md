# Where docs.ficsit.app is wrong or outdated (SML 3.12, game 513885)

Part of the `satisfactory-modding` skill. docs.ficsit.app "latest" was partly written before SML 3.12 was released. The statements below were checked against SML 3.12.0, the game headers of changelist 513885 and the CSS engine on 2026-10-24. Check names in the code before copying them from the docs: a wrong name from a docs example costs a build. Pages are named by their title or topic; paths are relative to the SML source (`Mods/SML/Source/SML`), the game headers (`Source/FactoryGame/Public`) or the engine (`Engine/Source`). Markers as everywhere in the skill: **[source]** = read in code, **[?]** = undecided or not checked. Every bullet: (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app).

## 1. ModLoader (SML API)

- **Modules / Registry**: docs say mods register key binds (`RegisterModKeyBind`, `RegisterModAxisBind`) and a Subsystem Holder on the instance module; neither exists in SML 3.12. The SML 3.12 form is in `references/sml-api.md`. **[source]**
- **Cpp_hooking**: docs name `SUBSCRIBE_METHOD_MANUAL` for overloads; only the `_EXPLICIT` variants exist. The SML 3.12 form is in `references/sml-api.md`. **[source]**
- **Cpp_hooking, BpHookMigrationGuide**: docs still show C++ hooking of Blueprint functions and Blueprint SCS hooks; they were removed in SML 3.11. The SML 3.12 form (Actor Mixins) is in `references/sml-api.md`. **[source]**
- **BlueprintInterface**: docs say `GetLoadedMods()` returns strings, `FModInfo` has `ModId, Authors, Credits` and the version call is `GetSMLVersion`; none of this matches the code. The SML 3.12 form is in `references/sml-config-networking.md`. **[source]**
- **Configuration**: docs name the editor menu entries differently from SML 3.12. The SML 3.12 form is in `references/mod-structure.md` (`SMLEditor`). **[source]**
- **Configuration**: docs show `ReloadModConfigurations(bool bSaveOnSchemaChange)`, `RegisterModConfiguration(FConfigId, Class)`, a colour property and `Mark Property Dirty`; the code has other signatures and no colour property. The SML 3.12 form is in `references/sml-config-networking.md`. **[source]**
- **Configuration / FAQ "Mod Configuration Files"**: docs say only "Configs folder"; the file path with a category is in `references/sml-config-networking.md`. **[source]**
- **Registry, ContentTagRegistry**: docs say the Mod Content Registry and Content Tag Registry are game instance subsystems; in the code they are world subsystems. The SML 3.12 form is in `references/sml-content-sessions.md`. **[source]**
- **Subsystems**: docs say "BeginPlay is called as part of Initialization"; the code calls `DispatchInit()` at registration, before BeginPlay. The SML 3.12 form is in `references/sml-api.md`. **[source]**
- **SMLChatCommands (cheats)**: docs call `SML.ForceAllowCheats` a session setting; in the code it is a CVar. Both exist: a save made with the setting on carries it in its header, and the CVar works from `-ExecCmds`, but a save loaded through `?loadgame=` does not apply the stored setting (tested 2026-10-24); see `references/sml-config-networking.md`, "Cheats in a test run".

## 2. Satisfactory game systems

- **Abstract Instance**: docs say `AAbstractInstanceManager::Get(World)`, `FInstanceHandle*` handles and `RemoveInstances(..., bEmptyHandleArray)`; the SML 3.12 form is in `references/game-classes.md`. **[source]**
- **Clipboard**: docs say `GetClipboardSettingsClass`, which does not exist; the SML 3.12 form is in `references/game-systems.md`. **[source]**
- **Holograms**: docs give other build-mode signatures and `hitResult.Actor.Get()` (does not compile on UE 5.6); the SML 3.12 form is in `references/game-systems.md`. **[source]**
- **Holograms, `IsValidHitResult`**: the docs and the header comment disagree on what false means; undecided, no `.cpp`; see `references/game-systems.md`. **[?]**
- **Enhanced Input**: docs say `AFGPlayerController::SetMappingContextBound`, a "Parent Context" field on `UFGInputMappingContext` and `GetKeyNameForActionSimple`; none exists in game 513885. The SML 3.12 form is in `references/ui.md`. **[source]**
- **Conditional Replication**: docs leave out the owner's `FFGConditionalPropertyReplicator` member and `IsPropertyRelevantForConnection`, and advise against marking the inventory pointer `SaveGame`, which the game does; see `references/multiplayer.md`. **[source]**
- **Crafting**: docs show the editor labels ("M Manufacturing Duration"), not the C++ names; the SML 3.12 form is in `references/game-systems.md`. **[source]**
- **Multiplayer**: docs say `AFGPlayerController::GetRemoteCallObjectByClass`; only `GetRemoteCallObjectOfClass` exists. The SML 3.12 form is in `references/sml-config-networking.md`. **[source]**
- **Multiplayer**: docs say `FGPlayerController::RegisterRemoteCallObjectOfClass`; the code has `RegisterRemoteCallObjectClass`. The SML 3.12 form is in `references/sml-config-networking.md`. **[source]**
- **Savegame**: docs say `AFGBuildable` does not return true in `ShouldSave`; the code does, so no override is needed. The SML 3.12 form is in `references/game-classes.md`. **[source]**
- **ResourceSink**: docs know one table per world module; the code has two tracks (Default and Exploration). The SML 3.12 form is in `references/sml-content-sessions.md`. **[source]**
- **Schematic**: docs say the flag is `HasPickedUpItem`; the code has `mRememberPickUp`. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **Inventory**: docs say item state is "any kind of actor"; in the code it is an `FFGDynamicStruct`. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **FactoryConnectors**: docs say `FactoryGrabOutput`/`FactoryPeekOutput` and a "M Connector" property; neither exists. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **OreScanner**: docs say to call `AFGResourceScanner::GenerateNodeClustersAccessor`, which does not exist. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **IconLibrary**: docs say `ESIT_Map_Stamp`; the code has `EIconType::ESIT_MapStamp`. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **ShoppingList**: docs say `FGShoppingListObject_Object` and a getter without arguments. The SML 3.12 form is in `references/game-systems.md`. **[source]**
- **GameFeatureDataAsset**: docs list 7 primary asset types the base game scans; the base game config has 12. The list is in `references/mod-structure.md`. **[source]**
- **ConveyorRendering**: docs page is marked outdated; `UFGConveyorItemUserData` still exists. **[?]**

## 3. C++ setup, debugging, tools

- **Cpp_debugging ("Attach Debugger")**: docs say attach to `FactoryGame-Win64-Shipping.exe`; the install has `FactoryGameSteam-Win64-Shipping.exe` (EGS: `FactoryGameEGS-...`). The correct name is in `references/build-install-debug.md`. **[source]** (file on disk)
- **Cpp_debugging ("Asserts")**: docs imply `check()` is off in Shipping; in mod code `check()` and `ensure()` are live in Shipping. The detail is in `references/build-install-debug.md`. **[source]**
- **SMLEditor ("In Editor Testing Example")**: docs suggest testing in the editor to save relaunches. That holds for pure actor and widget logic only: `SML_ALLOW_PATCHES_IN_EDITOR=0` whenever `Source/FactoryGame/currentVersion.txt` exists (`SML.Build.cs:94-101`) and subsystems register only `!WITH_EDITOR` (`SatisfactoryModLoader.cpp:215`). **[source]**
- **TestingResources / ExtraLaunchArguments ("map options")**: docs list `?startloc=`, `?sessionName=`, `?DayLength=` and others and say themselves "from 2021, may be outdated"; only `skipOnboarding`, `listen`, `loadgame` are verified. The string search of the game DLL is in `references/testing-launch.md`. **[?]**
- **Cpp_setup ("Compiling")**: docs tell to rebuild the Development Editor target after a change of class structure; a risk with `-nocompileeditor`, not a docs error. The detail is in `references/build-install-debug.md` ("Stale editor DLLs"). **[?]**
- **Development_ExtractGameFiles / Asset Toolkit**: docs describe FModel and the dumper; `FactoryGame.usmap` and `CustomVersions.json` exist in `<Game>\CommunityResources` (checked), FModel itself and the Asset Toolkit were not run. See `references/setup.md` and `references/tools.md`. **[?]**

## 4. Beginner guide, project setup, release

- **dependencies, project_setup (Wwise)**: docs say Wwise 2025.1.6.9117 and list deployment platforms without Game Core; right for the current starter project master (CL 513885), the older master needed 2023.1.14.8770. The versions and platforms are in `references/setup.md`. **[source]**
- **project_setup ("Generate Sound Banks", "GeneratedSoundBanks folder does not seem to be set")**: docs tell to set Root Output Path and Unreal Audio Routing = Both; the steps only silence a popup, the skill was right. The detail is in `references/setup.md`. (checked on disk)
- **ReleaseMod**: docs say `RemoteVersionRange` "defaults to your SemVersion, both sides must have the exact same version"; the default is `>=` your version. The skill had it right; see `references/mod-structure.md`. **[source]**
- **ReleaseMod (example `.uplugin`)**: docs show SML `^3.9.0` and module `LoadingPhase: PostDefault`; outdated. The SML 3.12 form is in `references/mod-structure.md`. **[source]**
- **ReleaseMod, Alpakit.ini**: docs only show the Release Targets checkboxes; the file format (one `Targets=` line per target, a piped single line selects no target) is in `references/mod-structure.md`; the parsing was run in the packaged game, the Release button itself was not. **[?]** for the button.
- **ImportingAnotherMod ("Something is Still Wrong")**: docs blame the folder name for `DirectoryNotFoundException`; the cause is that UAT did not find the plugin by name, a folder name alone is not decided. See `references/build-install-debug.md`. **[?]**
- **StarterProject pages**: docs say take `dev` or `master`, whichever was pushed last; too vague, the skill was right. The comparison to make is in `references/setup.md`. **[source]**
- **project_setup (building the editor)**: docs build the FactoryGame project in Visual Studio; `Build.bat FactoryEditor Win64 Development` works without a solution, see `references/setup.md`. The docs route is optional; the skill was right. (checked in practice)
- **ReleaseMod / version**: docs say `Version` and `SemVersion` should match; SML ignores `Version` when `SemVersion` parses (`references/mod-structure.md`). Whether ficsit.app checks it is unknown. **[?]**
- **UploadToSMR, Tags (ficsit.app)**: docs say Mod Manager tag filtering cannot be done, yet also describe SMM filtering by tag (all/any). The two pages disagree. **[?]**

## 5. Updating between versions, Unreal Engine

- **UpdatingToNewVersions (3.7)**: docs say "configure release targets" only; the skill's old `Targets=` form was wrong, the right one is in `references/mod-structure.md` (parsing tested, 2026-10-24).
- **UpdatingToNewVersions (3.12)**: docs say 99 % of mods need a Game Feature Data asset; a mod with no content to register may live outside GameFeatures, both statements hold. The detail is in `references/mod-structure.md`. **[source]**
- **CoreRedirect**: docs example uses `MatchSubstring=true`, which the engine deprecates in favour of `MatchWildcard`; the SML 3.12 form is in `references/updating.md`. **[source]**
- **UpdatingToNewVersions**: docs say `UE4Editor.exe`. The 5.6 CSS editor is `Engine\Binaries\Win64\UnrealEditor.exe`. **[source]** (file on disk)
- **UpdatingToNewVersions (3.12, UHT pointer setting)**: docs show `NonEngineNativePointerMemberBehavior=Disallow` without a file; it has no effect in the project's `DefaultEngine.ini`. The SML 3.12 form is in `references/updating.md` and `references/patterns-and-pitfalls.md`, item 35. **[source]**
- **UpdatingToNewVersions (3.12, raw pointers)**: docs say raw `UObject*` UPROPERTY members risk GC crashes and a later SML will refuse them; the crash risk is docs only. See `references/patterns-and-pitfalls.md`, item 35. **[?]**
- **Localization**: docs mark the system "not fully ready" (compile, package and Tolgee steps are TODO). The engine has the CSS "Plugin Localization Target" (`Developer/Localization/Private/PluginLocalizationManager.cpp`). Whether translations mount for a game feature mod is not tested (the state machine calls the explicit-plugin mount, which only warns). **[?]**
- **ForUsers_CoreRedirectMigration**: docs say an `Engine.ini` in `<Game>\FactoryGame\Mods\SML\Config` works for users and should be removed after one save. Which ini file name the plugin layer reads is not verified. **[?]**
- **UpdatingToNewVersions (pre-1.2 assets)**: docs say assets once auto-detected must now be listed in the game feature data's "Primary Asset Types to Scan"; not checked in a built mod. See `references/updating.md`. **[?]**

## 6. FAQ, users, community resources

- **ForUsers_DedicatedServerSetup**: **[?]** docs say SMM >= 3.0.0 and ficsit-cli manage server installs (local, SFTP/FTP, SMB); on disk: `%APPDATA%\ficsit\installations.json` lists the server and server mods carry `.smm` markers. The skill said the server has no mod manager, which holds only for a self-built mod that SMM cannot download. See `references/build-install-debug.md`.
- **TrainSignalGuide (Signals)**: docs say "trains only look for signals on the right-hand side"; wrong: Left Side block and path signals stop and release trains exactly like Right Side ones (tested 2026-10-25). The detail is in `domains/railroad/signals.md`.
- **TrainSignalGuide ("all or nothing")**: docs say signals are all or nothing; a partly signalled network ran two trains without errors or deadlock, only with less capacity (tested 2026-10-25), so it is advice. The detail is in `domains/railroad/signals.md`.
- **TrainSignalGuide (Rails)**: docs say rails can cross and "clip" with no adverse effect; true for train movement, for block logic crossing tracks and tracks closer than 6 m share a block (`domains/railroad/signals.md`). Both right. **[source]**
- **TrainSignalGuide (build limits)**: docs say the smallest curve is 3x3 Foundations and stacked rails need 12 m; wrong as game limits: the track hologram allows a 15 m bend radius (a 2x2 curve) and a track keeps only 0–1 m above the rail clear. The 2 m ramp limit is wrong too: track builds up to 25° and trains (a locomotive with a loaded Freight Car) climbed 24.2° (tested 2026-10-25). The detail is in `domains/railroad/test-layouts.md`.
- **TrainSignalGuide (block spacing)**: docs text reads "1.5 to train lengths apart" (garbled, probably "1.5 to N"). It is capacity advice: the game enforces no block length, blocks of any length worked (2026-10-26). The number is not checked. **[?]**
- **TrainSignalGuide and wiki (signal distances, read through a summary)**: "trains slow down for a red signal about 250 m ahead" (wiki) is wrong for a light train, which began braking 152 m ahead from 120 km/h; "a signal sits at least 12 m from the end of a track piece" is wrong for the signal logic: signals 1 m and 4 m from a free end are valid (tested 2026-10-26; the build gun's spot rule not tried **[?]**). The detail is in `domains/railroad/signals.md`.
- **faq ("Game Screenshots")**: docs say `%UserProfile%\Documents\My Games\FactoryGame\Screenshots`. The test machine has only `FPaths::ScreenShotDir()` = `...\Saved\Screenshots\Windows\`; the Documents folder does not exist. Docs path (player key screenshots) not found. **[?]**
- **Development_OpenSourceExamples**: the page predates Actor Mixins and the Blueprint hook systems; see `references/tools.md`. **[?]**
- **ConfiguringMods, faq**: docs fit the code on the save header mod list (`SMLWorldModule.cpp:31-52`), SessionSettings in the map-travel URL and `-EpicPortal -NoSteamClient`; no error found. The header does carry `?SessionSettings=` (tested), but a save loaded by `?loadgame=` does not restore them (`references/sml-content-sessions.md`).

## 7. Where the docs were right and the skill had to change

For the other direction (docs right, skill wrong or incomplete) the corrected places are:

- C++-only root module (`bRootModule = true` in a C++ class) is found by SML: `PluginModuleLoader.cpp:35-60` unions native classes with asset-registry Blueprint classes. Tested for the instance and the world module: every lifecycle phase ran, no two-roots Fatal (`references/sml-api.md`).
- Wwise 2025.1.6.9117 is the current path; the 2023 version belongs to the older starter project master. **[source]**
- Server mod manager and the config path with a category (sections 6 and 1 above).
- Freight Platforms (TrainSignalGuide): docs say stations lock for about 27 s and give or take nothing from belts in that time; right, tested 2026-10-24: solid-cargo belts stand still in every loading and unloading phase (`domains/railroad/timetable-docking.md`).
