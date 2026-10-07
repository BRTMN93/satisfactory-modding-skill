# SML: modules, hooks, config, networking, commands, content

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 4. SML: modules and lifecycle

**Module types**
- `UGameInstanceModule`: one per game instance, lives through all worlds. Also runs on a dedicated server.
- `UGameWorldModule`: one per world, also on clients.
- `UMenuWorldModule`: main menu only.

**Phases** (`ELifecyclePhase`): `CONSTRUCTION`, `INITIALIZATION`, `POST_INITIALIZATION`.
- Override `virtual void DispatchLifecycleEvent(ELifecyclePhase)` and **always call `Super`**. In `INITIALIZATION`, SML registers the module's arrays inside it.

**When things happen**
- Instance modules go through all three phases at once at game start, before any world.
- World modules get `CONSTRUCTION` and `INITIALIZATION` at `OnActorsInitialized`, and `POST_INITIALIZATION` at the world's BeginPlay.
- In a world module's `POST_INITIALIZATION`, buildings from the save are already registered.
- `AModSubsystem::Init()` fires before the world's BeginPlay. Set "loading in progress" flags there.
- Measured on a save load:
  1. `AModSubsystem::Init`,
  2. the world module's `CONSTRUCTION` and `INITIALIZATION` right after `LogGame: World Serialization (load)`,
  3. `POST_INITIALIZATION` about 1.5 s later, before `LogLoad: Took N seconds to LoadMap(...)`.
- In `POST_INITIALIZATION`, and on the next tick via `GetTimerManager().SetTimerForNextTick`, the save's railway data is readable: `AFGRailroadSubsystem::GetAllTrainStations`, `GetAllTrains` and `AFGBuildableSubsystem::GetTypedBuildable<AFGBuildableTrainPlatformCargo>`.
- `AFGRailroadSubsystem::Get(World)` returns null in the main menu world. That makes a good "game world only" guard.

**What to do in which phase**
- `CONSTRUCTION`: your own state and subsystems. The instance config is not registered yet.
- `INITIALIZATION`: content registration, reading the config.
- `POST_INITIALIZATION`: things that depend on other mods, installing hooks.

**Arrays filled in the root Blueprint**
- Instance module: `ModConfigurations`, `BlueprintHooks`, `ClientBlueprintHooks`, `WidgetBlueprintHooks`, `GlobalItemTooltipProviders`, `GameMaps`, `SessionSettings`, `RemoteCallObjects`. On a dedicated server the "Client" ones are skipped.
- World module: `ModSubsystems` (spawned in `CONSTRUCTION`), `mSchematics`, `mResearchTrees`, `mChatCommands`, resource sink point tables, `mContentTagAdditionsTable`.
- A world module's `ModSubsystems` can be set in the constructor of the C++ class (`ModSubsystems.Add(AMySubsystem::StaticClass())`), and the Blueprint child inherits that value. Then only **Root Module** needs ticking in the root Blueprint. The subsystem is spawned on a save load: a log line from its `AModSubsystem::Init()` override appears before the world module's phases. (2026-10-02, game 502094, SML 3.12.0)

**Root pattern**
- A C++ class **without** `bRootModule` + a Blueprint child `RootInstance_<Mod>`, `RootGameWorld_<Mod>` or `RootMenuWorld_<Mod>` with `bRootModule = true`.
- Exactly one root of each type per mod, otherwise Fatal.
- Do not set `bRootModule` in the C++ class. The Blueprint child would inherit it and you would get two roots.
- The order of mods within a phase is undefined.
- **Root modules must be Blueprint assets, because SML looks for them only in the asset registry.** `PluginModuleLoader.cpp:39-41` calls `FindBlueprintAssetsByTag(..., "bRootModule", {"True"})`. A C++ class with `bRootModule = true` would not be found at all, so this pattern (a C++ class without the flag plus a Blueprint child with the flag) is the only way, not just good practice. Blueprint roots work: in the game the instance module logged `CONSTRUCTION`, `INITIALIZATION` and `POST_INITIALIZATION`.
- **A validation error on the first save of a module Blueprint is normal.** Saving before ticking **Root Module** gives this in the editor log: `AssetCheck: Error: [AssetLog] …Root….uasset: At least one module of this type was found in this mod, but none were marked as root. Fix by marking at least one as root.` After ticking the flag and saving again, validation passes without an error. The flag is in **Class Defaults**, in the **Details** panel, named **Root Module**.

**Finding other mods' modules**
- `UGameInstanceModuleManager::FindModule(FName)`, `UWorldModuleManager::FindModule`.
- On the client, check `AFGGameState::AreClientSubsystemsValid()`.

**World teardown**
- Use `FWorldDelegates::OnWorldBeginTearDown.AddUObject(...)`.
- The delegate fires **twice** before a save loads from the menu: for the menu world and for the transition world. Check `World == GetWorld()`.

```cpp
UCLASS() class MYMOD_API UMyGameInstanceModule : public UGameInstanceModule {
    GENERATED_BODY()
public: virtual void DispatchLifecycleEvent(ELifecyclePhase Phase) override;
};
void UMyGameInstanceModule::DispatchLifecycleEvent(ELifecyclePhase Phase) {
    Super::DispatchLifecycleEvent(Phase);            // SML registers configs, BP hooks, RCOs here
    switch (Phase) {
    case ELifecyclePhase::CONSTRUCTION:        break; // config not registered yet
    case ELifecyclePhase::INITIALIZATION:      break; // GetActiveConfig() works now
    case ELifecyclePhase::POST_INITIALIZATION:
        if (!WITH_EDITOR) { InstallHooks(); }        // all mods initialized
        break;
    }
}
// Then a Blueprint RootInstance_MyMod with bRootModule=true and the arrays filled in.
```

## 5. SML: hooks

Header: `#include "Patching/NativeHookManager.h"`. All macros return `FDelegateHandle`.

**Macros**
- `SUBSCRIBE_METHOD(&Class::Method, Handler)`: any function, globally.
- `SUBSCRIBE_METHOD_VIRTUAL(&Class::Method, SampleObject, Handler)`
- `SUBSCRIBE_UOBJECT_METHOD(Class, Method, Handler)`: the sample object is `GetDefault<Class>()`.
- Variants: `*_AFTER`, `*_EXPLICIT(Signature, ...)` for overloaded functions, `UNSUBSCRIBE_METHOD` and `UNSUBSCRIBE_UOBJECT_METHOD`.

**Handlers**
- "Before": `void(TCallScope<Sig>& Scope, Class* Self, Args...)`. Static and free functions have no `Self`.
  - `Scope(Self, Args...)` calls the original.
  - `Scope.Cancel()` skips the original (void functions). `Scope.Override(v)` skips it and sets the result (functions with a result).
  - Simply returning from the handler without calling `Scope` still runs the original.
- "After": for void functions `void(Class* Self, Args...)`, and for functions with a result **the result comes first**: `void(const Ret& Result, Class* Self, Args...)`. "After" hooks always fire, even after `Cancel`.
- **[source]** In a hook on a **member** function that returns a class by value (a `TWeakPtr`, a `TSharedPtr`, an `FString`, any struct), call the original through `Scope(...)` before `Scope.Override(...)`.
  - SML's thunk for that case, `HookInvokerExecutorMemberFunction::ApplyCallUserTypeByValue` (`Patching/NativeHookManager.h`), gets the caller's hidden return slot `OutReturnValue`, lets the original construct the result there, and at its end always runs `*OutReturnValue = Scope.GetResult();`, an assignment and not a construction.
  - When no handler called the original, the slot is still uninitialized stack memory, and the assignment operator treats it as a live object: for a smart pointer it releases a reference through a garbage pointer.
  - So a handler that wants to return an empty result calls the original first, undoes what the original did, and then overrides. That order ran about 25 000 times in the packaged game on `FFGRailroadSignalBlock::CreatePathReservation`, which returns a `TWeakPtr`, without a crash. The other order was not tried.
  - Static and free functions are not affected (`HookInvokerExecutorGlobalFunction::ApplyCall` returns by value the normal way), and neither are scalar results (`ApplyCallScalar`).
  - Evidence: SML 3.12.0, `Mods/SML/Source/SML/Public/Patching/NativeHookManager.h`, `ApplyCallUserTypeByValue`. (2026-10-03, SML 3.12.0)
- Handlers run in registration order.
- Lambdas live until the end of the game. Capture `this` and values, never local variables by reference.

**Limits**
- One hook per function address, shared by all mods. A failed hook installation is Fatal.
- The method must be accessible. For private ones, use `Friend` from AccessTransformers.
- `inline` and `FORCEINLINE` functions cannot be hooked, e.g. `AFGBuildableSubsystem::GetAllBuildablesRef`.
- Engine classes that are not exported cannot be inherited. You have to copy the whole class, e.g. `FCanvasBatchedElementRenderItem`.
- Install hooks in `if (!WITH_EDITOR)`.

**⚠ Biggest trap: a hook fires for every instance in every world**
- The first line of the handler filters to *your* object, and in all other cases passes the call through `Scope(...)`.
- Real example: a global hook on `FCanvas::GetBatchedElements` replaced the draw batches of *all* canvases in the game. After a few save loads the game used 16 GB of VRAM.
- Null out pointers to your own objects that you compare against in the hook after use.

**If the game has a delegate, use it instead of a hook**
- `AFGPlayerController::PlayerControllerBegunPlay` (static) and `ChatMessageEntered`
- `AFGBuildableSubsystem::mBuildableAddedDelegate`, `mBuildableRemovedDelegate`, `BuildableConstructedGlobalDelegate`
- `AFGSchematicManager::PopulateSchematicListDelegate`
- **[?]** It is unknown whether the building delegates fire on clients and for lightweight buildings.

**Hook targets verified in practice**
- `AFGBuildableSubsystem::AddBuildable` and `RemoveBuildable`: actor buildings.
- `AFGLightweightBuildableSubsystem::AddFromBuildableInstanceData`: has a `FromSaveData` parameter, skip such calls.
- `AddFromReplicatedData`: client side.
- `InvalidateRuntimeInstanceDataForIndex`: removal of lightweight buildings.
- `AFGHUD::CloseRespawnUI`: the player has finished joining, you can send data from here.
- `UFGSaveSession::SaveGame(const FString&, FOnSaveGameComplete, void*)`: the "after" hook fires on manual save and on autosave (`<session>_autosave_0..2`). The serialization itself happens at the end of the frame.
- `FRailroadNavigation::FindPathSync(AFGLocomotive*, AFGBuildableRailroadStation*, FRailroadGraphAStarFilter)`: a static member function that returns a struct by value. A "before" hook on it works:
  `SUBSCRIBE_METHOD(FRailroadNavigation::FindPathSync, [](auto& Scope, AFGLocomotive* Locomotive, AFGBuildableRailroadStation* Station, FRailroadGraphAStarFilter Filter) { … })`
  - There is no `Self` argument.
  - `Scope(Locomotive, Station, Filter)` runs the original and returns its result. `Scope.Override(Result)` replaces it. A handler that returns without touching `Scope` lets the original run.
  - Log line: `LogNativeHookManager: Display: Successfully hooked function FRailroadNavigation::FindPathSync at 00007FFD5FAD6D90`.
  - A train drove the route given through `Override` (`domains/railroad/own-routes.md`, "Giving the autopilot a route of your own").
- **Hook targets in the railway signalling, verified.** All four installed in `POST_INITIALIZATION` with `SUBSCRIBE_METHOD` (plain structs, no sample object) and fired on the game thread:
  - `FFGRailroadSignalBlock::GetAspectFor`, a const method returning an enum: `[](auto& Scope, const FFGRailroadSignalBlock* Self, AFGBuildableRailroadSignal* Signal)`. `Scope(Self, Signal)` returns the game's aspect, `Scope.Override(ERailroadSignalAspect::RSA_Stop)` replaces it.
  - `FFGRailroadSignalBlock::CreatePathReservation`, returning a `TWeakPtr` by value: `[](auto& Scope, FFGRailroadSignalBlock* Self, AFGTrain* Train, AFGBuildableRailroadSignal* EntrySignal, int32 EntryPathSegment, FRailroadPathSharedPtr TrainPath)`. `CreateExclusiveReservation` is the same without the last argument.
  - `FFGRailroadBlockReservation::Approve`, a void method: `[](auto& Scope, FFGRailroadBlockReservation* Self)`. The train and the entry signal are public members of `Self` (`Train`, `EntrySignal`).
  - With the handlers rejecting every call in their first line, a train's pass showed the same aspects at the same distances and speeds as in a run without the hooks. Call rates in a world with three trains and 16 signals: `GetAspectFor` 1.3 a second, reservation creation and approval 0.25 a second each.
  - What these hooks do to trains: `domains/railroad/signals.md`, "Holding a train at a signal with hooks". Log lines: `Successfully hooked function FFGRailroadSignalBlock::GetAspectFor at …`, the same for the other three. (2026-10-03, game 502094, SML 3.12.0)
- Placing one blueprint with buildings triggers about 300 hooks. Merge such series into one batch of work.

```cpp
// "Before" with an instance filter
FDelegateHandle H = SUBSCRIBE_UOBJECT_METHOD(AFGBuildableFactory, SetIsProductionPaused,
    [this](auto& Scope, AFGBuildableFactory* Self, bool bPaused) {
        if (!Self->HasAuthority() || !IsMine(Self)) return;  // not mine: the original runs anyway
        if (bPaused) { Scope.Cancel(); return; }             // skip the original
        Scope(Self, bPaused);                                 // explicit call of the original
    });

// "After" for a void function and for a function with a result (result first!)
SUBSCRIBE_UOBJECT_METHOD_AFTER(AFGBuildableSubsystem, AddBuildable,
    [this](AFGBuildableSubsystem* Self, AFGBuildable* B) { OnBuilt(B); });
SUBSCRIBE_UOBJECT_METHOD_AFTER(AFGLightweightBuildableSubsystem, AddFromBuildableInstanceData,
    [this](int32 Index, AFGLightweightBuildableSubsystem* Self, TSubclassOf<AFGBuildable> Class,
           FRuntimeBuildableInstanceData& Data, bool bFromSave, int32 SaveIdx, uint16 ConstructId,
           AActor* Instigator, int32 BpIdx) { if (!bFromSave) OnLightweightBuilt(Class, Data.Transform); });

// Global hook on a non-UObject class: pass through everything that is not yours
SUBSCRIBE_METHOD(FCanvas::GetBatchedElements, [](auto& Scope, FCanvas* Self, /* ...arguments... */) {
    if (Self != MyCanvas) { Scope(Self /* , arguments */); return; }
    // ...your logic, result via Scope.Override(...)
});
```

**Blueprint hooks**
- "Blueprint Hook (SML)" and "Blueprint Mixin (SML)" assets.
- Hook definition (`FBlueprintHookDefinition`): `TargetFunction`, `HookFunction`, type `InsertionHook` or `RedirectHook`, place `BeforeTarget`, `AfterTarget` or `ReplaceTarget`, target specifier (`FunctionEntry`, `FunctionExit`, `ReturnValue`, `FunctionCall`, `PropertyAccess` and others).
- Registration: the `BlueprintHooks` and `ClientBlueprintHooks` arrays or `UBlueprintHookManager::RegisterBlueprintHook`. The target must be a function defined in a Blueprint.
- Per-actor state: `UBlueprintActorMixin`.
- Widgets: `UWidgetBlueprintHookData` in `WidgetBlueprintHooks`.
- **Widget hooks from C++, without an editor asset** (verified on the station, signal and locomotive windows, 2026-10-02, game 502094, SML 3.12.0):
  - Create the data with `NewObject<UWidgetBlueprintHookData>(GetTransientPackage())`.
  - Set `WidgetClass = TSoftClassPtr<UUserWidget>(FSoftObjectPath("/Game/…/Widget_X.Widget_X_C"))`.
  - Set `NewWidgetClass` (a plain C++ `UUserWidget` subclass is fine) and `NewWidgetName`.
  - Set `ParentWidgetName` and `ParentWidgetType`. `Direct_Any` worked for parents that are not variables, for example `HorizontalBox_0`. **[source]** Registration resolves the parent without the variable check (`ResolveParentWidget` passes `bCheckVariableName = false`), so `Direct` should resolve them too.
  - Register with `GEngine->GetEngineSubsystem<UWidgetBlueprintHookManager>()->RegisterWidgetBlueprintHook(Data)` in the instance module's `POST_INITIALIZATION`. The manager keeps the data alive.
  - Outside the editor the manager inserts the widget into the class archetype once, so every window created afterwards has it. Log line: `Installed widget blueprint hook … on WidgetBlueprint /Script/<Mod>.<Widget>`.
- **[source]** `UWidgetBlueprintHookSlot_Generic::SetupPanelSlot` (SML 3.12.0, `WidgetBlueprintHookManager.cpp`, the `UVerticalBoxSlot` branch) calls `HorizontalBoxSlot->SetSize(Size)` on a null pointer, so a Generic slot configuration crashes when the parent is a vertical box. Leave `SlotConfiguration` empty there and set the slot on the archetype after registering (`references/ui.md`, "Do not change the widget's slot in `NativeConstruct`"). (2026-10-02, SML 3.12.0)
- In the editor, all Blueprint hooking is disabled.
- **Trap:** a hook on one path does not catch the others. Example: closing the map with its key bypasses `Widget_MapContainer::CloseMap`, so you also have to listen for the widget's destruction or hiding.
- You can find the names of the game's Blueprint functions and variables in the `.uasset` stubs from the starter project: extract strings matching `[\x20-\x7e]{5,}` from the bytes.

## 6. SML: config, subsystems, networking, commands, content, tools

### 6.1 Config
- **Creating:** a Blueprint child of `UModConfiguration` with `FConfigId{ModReference, Category}`.
  - Properties: `UConfigPropertyBool`, `Float`, `Integer`, `String`, `Class`, `Array`, `Section`.
  - Flags: `bRequiresWorldReload` only restricts the UI to the menu, `bHidden`, `bAllowUserReset`.
  - **[source]** Slider in the mod's settings: use the classes `UCP_Integer` and `UCP_Float` from `Configuration/Properties/WidgetExtension/`. They have `WidgetType` (text field, slider `CPI_Slider` / `CPF_Slider`, spin box, and for integers also a list from an enum) and `MinValue` and `MaxValue`. They inherit from `UConfigPropertyInteger` and `UConfigPropertyFloat`, so reading the value from C++ does not change.
  - Registration through the `ModConfigurations` array, which happens in `INITIALIZATION`.
- **A configuration can be built entirely in C++, without an editor asset.** Make a non-abstract C++ child of `UModConfiguration` (set `ConfigId`, `DisplayName` in its constructor) and add its class to `ModConfigurations` in the game instance module's constructor. In `DispatchLifecycleEvent`, before calling `Super` in `INITIALIZATION` (SML registers the configurations there and reads the file at once), fill the class default object's `RootSection`: `NewObject` of SML's Blueprint property classes, loaded with `LoadClass<UConfigPropertySection>(nullptr, TEXT("/SML/Interface/UI/Menu/Mods/ConfigProperties/BP_ConfigPropertySection.BP_ConfigPropertySection_C"))` and likewise `BP_ConfigPropertyFloat`, `BP_ConfigPropertyBool`, with the CDO as outer; set `DisplayName`, `Tooltip`, `DefaultValue` and `Value`, and on the `UCP_Float` children `WidgetType` (`CPF_Slider`, `CPF_Spinbox`), `MinValue`, `MaxValue`; add each to `SectionProperties` under its key. These Blueprint children are what carries the menu widget; the bare C++ property classes have none.
  - Result in the packaged game: `LogSatisfactoryModLoader: Registering configuration /Script/<Mod>.<ConfigClass>`, `LogConfigManager: Display: Successfully loaded configuration from ../../../FactoryGame/Configs/<Mod>.cfg`, and the file written with every key and its default; a value set from code through the root section and `MarkDirty()` was read back from the file after a game restart.
  - For whole numbers use `BP_ConfigPropertyInteger` (`UCP_Integer`, `CPI_Slider`). A float slider shows two decimals (a grace period of 30 s became 61.47 s after a drag).
  - In the Mods menu each property shows its `DisplayName` left and the widget right: a slider has its value in a box on the right, a spin box (`CPF_Spinbox`) its value in the middle with arrows, so mixing the two in one list looks inconsistent, and a name longer than about 30 characters runs into the widget at 1440 px width. Keep names short and put the rest in `Tooltip`.
  - Values changed in the menu are written to the file at once. SML does not clamp a loaded float to `MinValue`/`MaxValue` (they only limit the widget), so check the values read from the file.
  - Evidence: packaged-game logs of 2026-10-03 20:16 and 20:31 UTC, two screenshots of Main menu -> Mods -> `<Mod>` taken by the user, the file after a slider drag (`"GraceSec": 61.466056823730469`). (2026-10-03, game 502094, SML 3.12.0)
- **Mod settings built in C++ were locked in the pause menu.** Config properties made with `NewObject<T>(Outer, LoadClass(".../BP_ConfigPropertyFloat_C" etc.))` could be changed from the main menu but did not react at all in the pause menu (sliders and bools). `UConfigProperty::bRequiresWorldReload` ("only editable from the main menu") was not set in code, so it came from the class defaults. Setting `Property->bRequiresWorldReload = false` on every property made all of them editable in a world, and the change went to the file (`Saved configuration to ../../../FactoryGame/Configs/<Mod>.cfg`). **[?]** That the Blueprint property classes default the flag to true was not read, only inferred from the fix. Also: a launch straight into a save (`GameDefaultMap` set to the save, as a test loop does) sends "Exit to Main Menu" back into that save, so the main menu cannot be reached in such a run. Evidence: the player's checks before and after the change, the config file. (2026-10-04, game 502094, SML 3.12.0)
- **File:** `<Game>\FactoryGame\Configs\<ModRef>.cfg`. It is JSON with the field `SML_ModVersion_DoNotChange`. In the game, edit the config in Main menu → Mods → `<Mod>`.
- **Reading from C++:** right-click the config asset → "Generate C++ Config Struct Header", then `F<Asset>Struct::GetActiveConfig(WorldContext)`. If the config is not registered yet or there is no world, you get a zeroed struct.
- **Writing:** `GetConfigurationRootSection(FConfigId)` → find the property → set `Value` → `MarkDirty()`. The change is saved after 0.2 s, and the values take effect immediately.
- **Tip:** expose time budgets and work limits in the config. In my case 1 ms per frame with 139k buildings meant 51 s of work.

```cpp
const FMyMod_ConfigStruct Cfg = FMyMod_ConfigStruct::GetActiveConfig(GetWorld());
UConfigManager* CM = GetGameInstance()->GetSubsystem<UConfigManager>();
const UConfigPropertySection* Root = CM->GetConfigurationRootSection(FConfigId{"MyMod", ""});
if (auto* P = Cast<UConfigPropertyFloat>(Root->SectionProperties.FindRef(TEXT("Speed")))) { P->Value = 2.f; P->MarkDirty(); }
```

### 6.2 Subsystems
- `AModSubsystem : AFGSubsystem` with the `ReplicationPolicy` field:
  - `SpawnOnServer`, `SpawnOnServer_Replicate`: everywhere except `NM_Client`,
  - `SpawnOnClient`: everywhere except a dedicated server,
  - `SpawnLocal`: everywhere.
- Override `Init()`, which fires before BeginPlay. Call `Super` in BeginPlay and EndPlay.
- Registration through `ModSubsystems` or `USubsystemActorManager::RegisterSubsystemActor`.
- Getting it: `World->GetSubsystem<USubsystemActorManager>()->GetSubsystemActor<T>()`. Returns null until the actor is created or arrives through replication.

**Keeping a subsystem's data in the save**
- `AModSubsystem` and `AFGSubsystem` do not implement `IFGSaveInterface`. Add it yourself: `class AMySubsystem : public AModSubsystem, public IFGSaveInterface`, override `ShouldSave_Implementation() const`, and mark the fields `UPROPERTY(SaveGame)`. The interface's other native events have empty defaults in the generated header, so override only what you need.
- SML spawns the subsystem with the fixed name `<ModReference>_<ClassName>` and first looks for an actor with that name loaded from the save (`USubsystemActorManager::SpawnSubsystemActor`). The saved actor with its data is reused instead of a fresh one.
- Round-tripped exactly through three save/load cycles: `int32`, `double` (bit-exact), `FString` with non-ASCII characters and quotes, `TMap<FString, FString>`, and `TMap<FString, TObjectPtr<AActor>>` holding a train station identifier, a station building, an `AFGTrain` and block signals. After each load every reference pointed to the same live object that `AFGRailroadSubsystem` and `AFGBuildableSubsystem` return.
- Order on a save load: `PostLoadGame` fires **before** `Init()`, both in frame 0 (measured 13.058 s and 13.163 s), so the `SaveGame` fields already hold the saved values inside `Init()`. On a save without the subsystem's data, or in a new game, `PostLoadGame` is not called and `Init()` sees the defaults.
- `PreSaveGame` fires on every save, also on saves made from code, while `ShouldSave` returns true. With `return DataVersion != 0;` an empty subsystem stays out of the save entirely (no `PreSaveGame` call). Do that in a mod players may install without using: a game saved with the mod installed then carries no trace of it.
- What a save without the mod does to this data: see "Saves" in `game-classes.md`.

### 6.3 Networking: client ↔ server RPC (Remote Call Object)
- `UFGRemoteCallObject` with `Within=FGPlayerController`, one per player.
- Functions: `UFUNCTION(Server, Reliable)` from client to server and `UFUNCTION(Client, Reliable)` from the server to that one client.
- Every RCO needs a dummy replicated property and `GetLifetimeReplicatedProps`.
- Registration: `RemoteCallObjects` on the instance module. Getting it: `PC->GetRemoteCallObjectOfClass<T>()`.
- The server can check whether the client has a given mod: `USMLRemoteCallObject::IsClientModInstalled` and `GetClientModVersion`.
- On a listen-server host, a `UFUNCTION(Server, Reliable)` of the local player's remote call object called from server code runs at once, inside the call: its log lines came in the same frame, before the next line of the caller. `PlayerController->GetRemoteCallObjectOfClass<T>()` returned the object about 1.5 s after the world started. Evidence: packaged-game log of 2026-10-03 20:21 UTC, frame counter `[  5]` on the call and on the server function's lines. (2026-10-03, game 502094, SML 3.12.0)

```cpp
UCLASS() class MYMOD_API UMyRCO : public UFGRemoteCallObject { GENERATED_BODY()
public:
    virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& Out) const override; // Super + DOREPLIFETIME(UMyRCO, bDummy)
    UFUNCTION(Server, Reliable) void ServerDo(int32 Arg);  // body in ServerDo_Implementation
    UFUNCTION(Client, Reliable) void ClientGot(int32 R);
protected: UPROPERTY(Replicated) bool bDummy = true;
};
// call: if (auto* R = PC->GetRemoteCallObjectOfClass<UMyRCO>()) R->ServerDo(1);
```

### 6.4 Chat commands [source]
- Class: a subclass of `AChatCommandInstance`. In the constructor set `CommandName`, `Aliases`, `Usage`, `MinNumberOfArguments`, `bOnlyUsableByPlayer`.
- Logic: override `ExecuteCommand_Implementation(UCommandSender*, const TArray<FString>&, const FString&)`, which returns `EExecutionStatus`.
- Registration: `mChatCommands`, server only, or `AChatCommandSubsystem::Get(World)->RegisterCommand(ModRef, Class)`.

### 6.5 Console commands
- `static FAutoConsoleCommandWithWorldArgsAndOutputDevice X(TEXT("MyMod.Cmd"), TEXT("description"), FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda(...));` works in a Shipping build. Open the console with the `~` key.
- Write to the console through `Ar.Log` and `Ar.Logf`. `UE_LOG` entries at Display level also show up there.

### 6.6 Content registration [source]
- `UModContentRegistry::Get(WorldContext)`: `RegisterSchematic`, `RegisterResearchTree`, `RegisterRecipe`, `RegisterResourceSinkItemPointTable` and the `GetRegistered*` queries.
- Items are not registered. They bind themselves through registered schematics and research trees. The simplest way is to put them in `mSchematics` and `mResearchTrees` on the world module.
- The registries close at the world's BeginPlay, so register in `INITIALIZATION` at the latest.
- A new building consists of a building Blueprint, a building descriptor and a recipe unlocked by a schematic. An example is in ExampleMod.
- Tags: `UContentTagRegistry`.

### 6.7 Other useful things from SML
- `UModLoadingLibrary`: `IsModLoaded`, `GetLoadedMods()` returns `TArray<FModInfo>{Name, Version}` (good as part of a cache key), `GetModLoaderVersion`.
- `UBlueprintAssetHelperLibrary::FindPluginNameByObjectPath`: which mod a given asset belongs to.
- `FReflectionHelper::GetPropertyValue`, `SetPropertyValue`, `CallScriptFunction`: access any property by name. Alternative in plain UE: `FindPropertyByName` + `ContainerPtrToValuePtr` and `CallFunctionByNameWithArguments`.
- Saving your own objects in the save: `IFGSaveInterface` + `UPROPERTY(SaveGame)`, tested on a subsystem (section 6.2). Mod metadata: `UFGSaveSession::SetModMetadata` and `GetModMetadata` [source].
- SML console variables:
  - `SML.SkipModCompatibilityCheck`
  - `SML.ForceAllowCheats`
  - `SML.DumpBlueprintPatchingResults`
  - `SML.SkipRemoteModListCheck`
- The `-WaitForDebugger` parameter works in Shipping [source].
- Logs from Blueprints: `UBlueprintLoggingLibrary`, writes as `Log<ModRef>`.
