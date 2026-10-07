# Game classes and data

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 7. Useful game classes

### Buildings: actors and lightweight
This is the most important thing to remember.
- `AFGBuildableSubsystem::Get(World)->GetAllBuildablesRef()` returns **actors only**.
- Foundations, walls and the like are **lightweight buildables**, meaning data only, without an actor. You get them through `AFGLightweightBuildableSubsystem::Get(World)->GetAllLightweightBuildableInstances()`, which returns `TMap<TSubclassOf<AFGBuildable>, TArray<FRuntimeBuildableInstanceData>>`.
  - Freed slots stay in the array and are reused. Skip entries where `!IsValid()` or `!BuiltWithRecipe`.
- Proportions in a large save: 33.7k actors and 105k lightweight instances. Collecting everything took 4–8 s, so you have to split it across frames.
- Expect unknown buildings from other mods. Give them fallback data and a log warning, not a crash.

- **`AFGBuildableSubsystem::mBuildableRemovedDelegate` fires for buildables dismantled from code and can drive a cache of railway pieces.** A `UObject` bound with `AddUniqueDynamic` to `mBuildableAddedDelegate` and `mBuildableRemovedDelegate` (both `FOnBuildableAdded`-style dynamic multicast delegates with one `AFGBuildable*` parameter) got one call for each of four signals and one track dismantled with `IFGDismantleInterface::Execute_Dismantle`; a once-a-second comparison of all tracks, signals and stations found no change the delegates had not announced. When bound in the first tick of a loaded world, the added delegate still fired for the save's train platforms (30 calls on a save with 11 stations) but not for its 142 tracks and 68 signals, so a first full read is needed anyway. Both delegates also fire for what the player does by hand: four tracks built, one dismantled, and a signal placed in the middle of a rail (the 48.00 m track actor is removed and two new ones of 32.39 m and 15.61 m appear, each announced). Not seen yet: a blueprint with tracks, and a station built while the game runs. Evidence: `13 build events so far, 0 changes without one` after the dismantling; `30 changes so far, 0 without a build event` at the first read; `0 changes without a build event so far` after each of six graphs rebuilt during the player's building. (2026-10-05, game 502094, SML 3.12.0)

### Factories
`AFGBuildableFactory`:
- `Factory_Tick` runs separately from the normal actor tick,
- `IsProducing`, `SetIsProductionPaused`, `GetPowerInfo`, `SetPendingPotential`.

### Saves
- `UFGSaveSession::Get(World)`: `SaveGame`, `LoadGame`.
- **Saving from code:** `UFGSaveSession::Get(World)->SaveGame(Name, FOnSaveGameComplete::CreateLambda([](bool bSaved, const FText& Error, void*) {...}), nullptr)`. The name is the file name without `.sav`. The file lands in the same `SaveGames\<SteamID64>` folder and keeps the session name of the loaded save. The callback came in the same frame as the call, about 90 ms later, with `bSaved = true`.
- Every save logs `LogSave: Warning: New/Old Root size mismatch!`, also a plain manual save in a game where no mod saves anything. It can be ignored.
- **A save loaded without the mod that wrote data into it loads without a fatal error, and the next save drops that data.** On load the game logs `LogUObjectGlobals: Warning: Failed to find object 'Class /Script/<Mod>.<Class>'`, `LogSave: Warning: Got object [...PersistentLevel.<Mod>_<Class>] of deleted class [...]` and an `Unknown Classes` list, and still ends with `NO LOAD ERRORS FOUND`. SML logs `<N> missing mods found: <Mod> (<Mod>) is missing` when the save list is shown. A save made in that session no longer contains the object. Loaded again with the mod, the subsystem is spawned fresh with default values. So one save without the mod loses everything the mod kept in the save.
- Location: `%LOCALAPPDATA%\FactoryGame\Saved\SaveGames\<SteamID64>\*.sav`. The same directory holds `blueprints\` and `ServerManager_V2.sav`.
- Autosaves cycle through three slots: `<session>_autosave_0..2`.
- A large factory is about 8 MB of file, because the save is compressed.

### Player and game state
- `AFGPlayerController`: `GetRemoteCallObjectOfClass`, `GetControlledCharacter`. Local player: `UFGBlueprintFunctionLibrary::GetLocalPlayerController`.
- `AFGGameState` has no static `Get`, you need `Cast<AFGGameState>(World->GetGameState())`. It gives access to the managers: `GetSchematicManager`, `GetResearchManager`, `GetRecipeManager`, `GetChatManager`, `GetMapManager`.
- Managers:
  - `AFGSchematicManager`: `GiveAccessToSchematic`, `IsSchematicPurchased`,
  - `AFGRecipeManager`: `AddAvailableRecipe`, `IsRecipeAvailable`,
  - `UFGInventoryComponent`: `AddStack`, `Remove`, `GetNumItems`.

### Map
- `AFGMapManager`: map markers.
- `UFGMapFunctionLibrary`: `GetWorldBounds`, `GetMapPosition`, `GetNormalizedPosition`, `GetWorldPosition`.
- The world is 750,000 × 750,000 cm (7.5 km). X from −324,698.83 to 425,301.83, Y from −375,000 to 375,000.
- The map zoom logic is in the `Widget_Map` Blueprint (`ZoomMap`, `GetZoomValue`, `mCurrentZoom`), not in C++. The zoom range is ×8.

### What changes between save and load
- Lightweight building transforms are bit-identical.
- Some actors (pipe junctions, pumps, flow indicators) get rotations recomputed with a drift of about 1e-10.
- Some actors get new names. Stations, trains and signals do not: `FGTrainStationIdentifier_<n>`, `Build_TrainStation_C_<n>`, `BP_Train_C_<n>` and `Build_RailroadBlockSignal_C_<n>` kept the same path name (`/Game/FactoryGame/Map/GameLevel01/Persistent_Level.Persistent_Level:PersistentLevel.<name>`) through four save/load cycles. A saved hard reference and the path name both identify them. Signals have no player-visible name. A position in a list sorted by name is no identity: after one signal was dismantled, the others moved down one place.
- A train's route is not saved (`AFGTrain::mAtcData` has no `SaveGame` flag). A train saved at 95 km/h on a route written by a mod came back in the first tick with no route, 0.43 m from where it was saved and at the same speed. In the second tick (0.4 s later) every train with the autopilot on had a new route from the game's own pathfinding. A train saved with the autopilot off came back parked in exactly the same place. Details: `domains/railroad/railroad.md`, "A train's route is not saved".
- **A reference to a dismantled object.** After `IFGDismantleInterface::Execute_Dismantle(Actor)` on a block signal, the `UPROPERTY` pointer is set and `IsValid` is true in the same frame. One second later the pointer is still set but `IsValid` is false. After `CollectGarbage` the pointer stored as a `TMap` value is null and the map key stays. Saved and loaded again, the key is still there with a null value. Test references with `IsValid`, not only for null.
- Other mods spawn helper buildings with a delay. Example: `EmptyActor_C` appeared about 2.5 s after load, at the player's location.
- Takeaway: compute data fingerprints only from what you use, rounded, and after data collection has finished.

### Game build number
- The file `<Game>\Engine\Binaries\Win64\*.version` (Changelist, GameVersion) or Steam's `appmanifest_526870.acf`.
- In the log: `LogInit: Engine Version / Net CL`.
