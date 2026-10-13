# SML: modules, lifecycle, hooks

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## SML: modules and lifecycle

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

## SML: hooks

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
- A static member function that returns a struct by value can be hooked with `SUBSCRIBE_METHOD`; the handler has no `Self` argument, `Scope(...)` returns the original result and `Scope.Override(Result)` replaces it. Verified on the game's route search: `domains/railroad/own-routes.md`, "Hooking the route search".
- Methods of plain structs (not `UObject`s) can be hooked with `SUBSCRIBE_METHOD` without a sample object, including const methods returning an enum and methods returning a `TWeakPtr` by value. Verified on the railway signalling: `domains/railroad/signals.md`, "Hook targets in the railway signalling".
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
