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

### Factories
`AFGBuildableFactory`:
- `Factory_Tick` runs separately from the normal actor tick,
- `IsProducing`, `SetIsProductionPaused`, `GetPowerInfo`, `SetPendingPotential`.

### Saves
- `UFGSaveSession::Get(World)`: `SaveGame`, `LoadGame`.
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
- Some actors get new names.
- Other mods spawn helper buildings with a delay. Example: `EmptyActor_C` appeared about 2.5 s after load, at the player's location.
- Takeaway: compute data fingerprints only from what you use, rounded, and after data collection has finished.

### Game build number
- The file `<Game>\Engine\Binaries\Win64\*.version` (Changelist, GameVersion) or Steam's `appmanifest_526870.acf`.
- In the log: `LogInit: Engine Version / Net CL`.
