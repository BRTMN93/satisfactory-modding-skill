# Game classes and data

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Useful game classes

### Buildings: actors and lightweight
This is the most important thing to remember.
- `AFGBuildableSubsystem::Get(World)->GetAllBuildablesRef()` returns **actors only**.
- Foundations, walls and the like are **lightweight buildables**, meaning data only, without an actor. You get them through `AFGLightweightBuildableSubsystem::Get(World)->GetAllLightweightBuildableInstances()`, which returns `TMap<TSubclassOf<AFGBuildable>, TArray<FRuntimeBuildableInstanceData>>`.
  - Freed slots stay in the array and are reused. Skip entries where `!IsValid()` or `!BuiltWithRecipe`.
- Proportions in a large save: 33.7k actors and 105k lightweight instances. Collecting everything took 4–8 s, so you have to split it across frames.
- Expect unknown buildings from other mods. Give them fallback data and a log warning, not a crash.

- **`AFGBuildableSubsystem::mBuildableRemovedDelegate` fires for buildables dismantled from code and can drive a cache of railway pieces.** A `UObject` bound with `AddUniqueDynamic` to `mBuildableAddedDelegate` and `mBuildableRemovedDelegate` (both `FOnBuildableAdded`-style dynamic multicast delegates with one `AFGBuildable*` parameter) got one call for each of four signals and one track dismantled with `IFGDismantleInterface::Execute_Dismantle`; a once-a-second comparison of all tracks, signals and stations found no change the delegates had not announced. When bound in the first tick of a loaded world, the added delegate still fired for the save's train platforms (30 calls on a save with 11 stations) but not for its 142 tracks and 68 signals, so a first full read is needed anyway. Both delegates also fire for what the player does by hand: four tracks built, one dismantled, and a signal placed in the middle of a rail (the 48.00 m track actor is removed and two new ones of 32.39 m and 15.61 m appear, each announced). Stations built and dismantled by the player while the game runs are announced the same way (5 → 6 → 7 → 8 stations, then 8 → 6; 182 build events in one manual session). Not seen yet: a blueprint with tracks, and dismantling many buildings at once. Evidence: `13 build events so far, 0 changes without one` after the dismantling; `30 changes so far, 0 without a build event` at the first read; `0 changes without a build event so far` after each of six graphs rebuilt during the player's building. (2026-10-05, game 502094, SML 3.12.0)
- **Listing one buildable class on a big save: `TActorIterator` over the world took 1.16 ms in one frame; `GetAllBuildablesRef()` can be read a part a frame.** A save with 1830 railway tracks among tens of thousands of actors: `TActorIterator<AFGBuildableRailroadTrack>` took 1.16 ms on the first load (0.4 ms on later loads in the same process). Walking `AFGBuildableSubsystem::GetAllBuildablesRef()` with a cursor, a `Cast` per entry and a budget check every 256 entries spread the same work over frames, longest frame 0.81 ms for the whole multi-stage task. A build event during the walk can move the list, so restart the walk when one comes. Evidence: `last read 4.51 ms in 73 frames, 1.161 ms in its longest frame` before, `read in 6.127 ms over 99 frames, the longest 0.814 ms` after, same track count. (2026-10-13, game 502094)
- **[?] Buildables inside a Blueprint Designer are not in `GetAllBuildablesRef()`, but an actor iterator finds them.** Three railway tracks built inside a Blueprint Designer showed up in a `TActorIterator` list (1 m higher, on the designer's floor) but were missing from a list built from `GetAllBuildablesRef()`; the same three tracks placed from the saved blueprint were in it. Not checked with the designer's own API. A mod that must ignore designer contents gets that for free from the buildables list; one that iterates actors has to filter them. Evidence: `new tracks [… 35.01 m unused; … 13.00 m unused; … 47.35 m unused; … 35.01 m not in the graph; … 13.00 m not in the graph; … 47.35 m not in the graph]`. (2026-10-13, game 502094)

### Factories
`AFGBuildableFactory`:
- `Factory_Tick` runs separately from the normal actor tick,
- `IsProducing`, `SetIsProductionPaused`, `GetPowerInfo`, `SetPendingPotential`.
- **Walking a factory along its belts and pipes works from the connection components, and it is cheap.** From any buildable, `TInlineComponentArray<UFGFactoryConnectionComponent*>` and `TInlineComponentArray<UFGPipeConnectionComponent*>` give its connections; `GetConnection()->GetOwner()` is the next buildable. Downstream means a belt connection with `GetDirection()` `FCD_OUTPUT` (or `FCD_ANY`) whose partner is not `FCD_OUTPUT`, and a pipe connection whose `GetPipeConnectionType()` is `PCT_PRODUCER` or `PCT_ANY` with a partner that is `PCT_CONSUMER` or `PCT_ANY` (pipes and junctions are `PCT_ANY`, so a fluid network is undirected between machines). Conveyor belts, lifts, splitters, mergers (also smart and modded multi-splitters/mergers), storage containers, train platforms (`AFGBuildableTrainPlatform` is an `AFGBuildableFactory` with the same connections) and modded production buildings that derive from `AFGBuildableManufacturer` all answer this way; `AFGBuildableManufacturer::GetCurrentRecipe()` with `UFGRecipe::GetProducts()` names what a machine makes. A truck station (`AFGBuildableDockingStation`) or drone port (`AFGBuildableDroneStation`) has both input and output connections, but items do not flow from one to the other, so a walk must stop there. Evidence: a walk from each station's freight platforms on a test save found `<station A>` → 3 splitters, 6 Smelters, 3 mergers → `<station B>` (49 buildings, 0.15 ms); on a player's save with 43 mods, 19 stations, 2325 buildings in 3.1 ms in total, at most 0.53 ms in a frame with a 0.5 ms budget checked every 16 buildings. (2026-10-18, game 513885, SML 3.12.0)

### Inventories, belts and game delegates
- Reading an inventory is cheap: `GetInventory()->GetNumItems(Item)` cost 0.10–0.20 µs per call on a 48-slot inventory, so polling once a second needs no change delegates (measured on train platforms: `domains/railroad/data-events.md`, "Polling platform stock is cheap").
- `AddStack` from code puts at most one stack into a slot: 50 000 units of water into a fluid wagon whose slot size said 1 600 000, and 100 ore into a Smelter's input buffer when 1000 were offered. Fluids count 1000 units per m³. Evidence: `domains/railroad/data-events.md`, "A Fluid Freight Car holds 2400 m³", and `domains/railroad/timetable-docking.md`, "What a backed-up belt line takes from a platform".
- Right after a save loads, empty belts and machines pull far more than their nominal rate until belts and input buffers fill: six Smelters (180/min nominal) took 950–1190/min for the first minutes, and a rate estimator with a 60 s window needed about 15 minutes to settle. Measure rates later or for longer (details: `domains/railroad/timetable-docking.md`).
- Dynamic delegates of game objects (for example `AFGTrain::mOnDockingStateChanged`) are bound from a `UObject` with `UFUNCTION` handlers (`AddDynamic`); keep that object alive (`AddToRoot` or a `UPROPERTY`). Example with the train delegates: `domains/railroad/data-events.md`.

### Items and recipes
- **The items a player can handle, for a picker:** the products and ingredients of the available recipes (`UFGRecipe::GetProducts`, `GetIngredients`), without building descriptors (`UFGBuildDescriptor`), customization (`UFGFactoryCustomizationDescriptor`), creatures (`UFGCreatureDescriptor`), sink credits (`UFGResourceSinkCreditDescriptor`) and the helper classes `UFGAnyUndefinedDescriptor`, `UFGNoneDescriptor`, `UFGOverflowDescriptor`, `UFGVisualizationModeDescriptor` and `UFGWildCardDescriptor`, without forms other than solid, liquid and gas, and without empty names. Evidence: 174 items with everything unlocked; typing `ir` in the picker left 5. (2026-10-04, game 502094, SML 3.12.0)

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

- **[source]** The "No Power" advanced game setting: `AFGGameState::GetCheatNoPower()` (`FGGameState.h:278`), a replicated `SaveGame` property. A mod that checks whether machines or vehicles have power must look at it first. `GetCheatNoPower()` is a `FORCEINLINE` read of `mCheatNoPower`, so it is only safe when the mod's headers match the game's changelist (between 502094 and 513885 the member moved, see `references/setup.md`, "5. Starter project"). `mCheatNoPower` is a `UPROPERTY( SaveGame, ReplicatedUsing=OnRep_CheatNoPower )`, so reading it through reflection (`FindFProperty<FBoolProperty>(AFGGameState::StaticClass(), TEXT("mCheatNoPower"))`) does not depend on the header layout. Evidence: `FGGameState.h:278` and `:773` at CL513885. (2026-10-05 and 2026-10-13, games 502094 and 513885)
- Reading `AFGGameState`'s "No Power" rule by reflection instead of the inline `GetCheatNoPower()` keeps working when the game moves the field: `FindFProperty<FBoolProperty>(AFGGameState::StaticClass(), TEXT("mCheatNoPower"))`, cached once, then `GetPropertyValue_InContainer(GameState)`. A check that calls `SetCheatNoPower(false)` / `(true)` and reads the value back this way passed on game 513885. An inline accessor compiled against older headers reads the old offset silently (see the 513885 note in `references/setup.md`), so a field a mod reads every frame from a game class that changes between updates is safer read by name. (2026-10-13, game 513885, SML 3.12.0)

### Map
- `AFGMapManager`: map markers.
- `UFGMapFunctionLibrary`: `GetWorldBounds`, `GetMapPosition`, `GetNormalizedPosition`, `GetWorldPosition`.
- The world is 750,000 × 750,000 cm (7.5 km). X from −324,698.83 to 425,301.83, Y from −375,000 to 375,000.
- The map zoom logic is in the `Widget_Map` Blueprint (`ZoomMap`, `GetZoomValue`, `mCurrentZoom`), not in C++. The zoom range is ×8.

### What changes between save and load
- Lightweight building transforms are bit-identical.
- Some actors (pipe junctions, pumps, flow indicators) get rotations recomputed with a drift of about 1e-10.
- Some actors get new names. Stations, trains and signals do not: `FGTrainStationIdentifier_<n>`, `Build_TrainStation_C_<n>`, `BP_Train_C_<n>` and `Build_RailroadBlockSignal_C_<n>` kept the same path name (`/Game/FactoryGame/Map/GameLevel01/Persistent_Level.Persistent_Level:PersistentLevel.<name>`) through four save/load cycles. A saved hard reference and the path name both identify them. Signals have no player-visible name. A position in a list sorted by name is no identity: after one signal was dismantled, the others moved down one place.
- **A reference to a dismantled object.** After `IFGDismantleInterface::Execute_Dismantle(Actor)` on a block signal, the `UPROPERTY` pointer is set and `IsValid` is true in the same frame. One second later the pointer is still set but `IsValid` is false. After `CollectGarbage` the pointer stored as a `TMap` value is null and the map key stays. Saved and loaded again, the key is still there with a null value. Test references with `IsValid`, not only for null.
- Other mods spawn helper buildings with a delay. Example: `EmptyActor_C` appeared about 2.5 s after load, at the player's location.
- Takeaway: compute data fingerprints only from what you use, rounded, and after data collection has finished.

### Game build number
- The file `<Game>\Engine\Binaries\Win64\*.version` (Changelist, GameVersion) or Steam's `appmanifest_526870.acf`.
- In the log: `LogInit: Engine Version / Net CL`.
