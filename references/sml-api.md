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
- `AModSubsystem::Init()` fires before the world's BeginPlay. Set "loading in progress" flags there. **[source]** The subsystem manager calls `DispatchInit()` at registration, which is the world module's `CONSTRUCTION`; `AModSubsystem::BeginPlay` calls it only if that has not happened yet (`SubsystemActorManager.cpp:11-43`, `ModSubsystem.cpp:9-14`). Warning: docs.ficsit.app says a subsystem's BeginPlay is called as part of initialization; in SML 3.12 / game 513885 `Init()` is the early hook and comes first (`SubsystemActorManager.cpp:11-43`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
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
- Instance module: `ModConfigurations`, `BlueprintHooks`, `ClientBlueprintHooks`, `WidgetBlueprintHooks`, `GlobalItemTooltipProviders`, `GameMaps`, `SessionSettings`, `RemoteCallObjects`. On a dedicated server the "Client" ones are skipped **[source]** (`GameInstanceModule.cpp:56`, `!IsRunningDedicatedServer()`; docs.ficsit.app says the same). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- Warning: docs.ficsit.app lists key-bind arrays (`RegisterModKeyBind`, `RegisterModAxisBind`) and a Subsystem Holder registry for the instance module. In SML 3.12 they do not exist: `GameInstanceModule.h:25-80` has no such arrays, `RegisterModKeyBind` appears nowhere in SML, `UModSubsystemHolder` is only forward-declared. `ModSubsystems` is on the world module, as below. A mod extends the game's input through `UFGChildInputMappingContext` (a primary data asset with `mParentContext`, game header `Input/FGChildInputMappingContext.h`). **[source]** (header read only). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- World module: `ModSubsystems` (spawned in `CONSTRUCTION`), `mSchematics`, `mResearchTrees`, `mChatCommands`, resource sink point tables, `mContentTagAdditionsTable`.
- A world module's `ModSubsystems` can be set in the constructor of the C++ class (`ModSubsystems.Add(AMySubsystem::StaticClass())`), and the Blueprint child inherits that value. Then only **Root Module** needs ticking in the root Blueprint. The subsystem is spawned on a save load: a log line from its `AModSubsystem::Init()` override appears before the world module's phases. (2026-10-02, game 502094, SML 3.12.0)

**Root pattern**
- A C++ class **without** `bRootModule` + a Blueprint child `RootInstance_<Mod>`, `RootGameWorld_<Mod>` or `RootMenuWorld_<Mod>` with `bRootModule = true`.
- Exactly one root of each type per mod, otherwise Fatal.
- Do not set `bRootModule` in the C++ class. The Blueprint child would inherit it and you would get two roots.
- The order of mods within a phase is undefined.
- **A root module can also be pure C++ [source].** `FPluginModuleLoader::FindRootModulesOfType` joins the native classes (`FindNativeClassesByType`) with the Blueprint assets tagged `bRootModule` (`FindBlueprintAssetsByTag`), skips Abstract, newer-version and deprecated classes, and keeps those whose class default object has `bRootModule` (`ModLoading/PluginModuleLoader.cpp:36-60`). The owning plugin of a `/Script/<Module>.<Class>` path comes from the module name (`BlueprintAssetHelperLibrary.cpp:121-135`). So a non-abstract C++ class that sets `bRootModule = true` in its constructor is a root; this was not run in the game. The recommended pattern (a C++ class without the flag plus a Blueprint child with the flag) stays right for a different reason: a flagged non-abstract C++ class **and** a flagged Blueprint child are two roots, which is Fatal (`GameInstanceModuleManager.cpp:51-55`, `WorldModuleManager.cpp:80`). Blueprint roots work: in the game the instance module logged `CONSTRUCTION`, `INITIALIZATION` and `POST_INITIALIZATION`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
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
- `SUBSCRIBE_METHOD_VIRTUAL(&Class::Method, SampleObject, Handler)`: **[source]** hooks the function body found in the sample object's vtable, so an override that does not call `Super` is not hooked; hook that class too (`NativeHookManager.cpp:103-110`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- `SUBSCRIBE_UOBJECT_METHOD(Class, Method, Handler)`: the sample object is `GetDefault<Class>()` (`NativeHookManager.h:625`).
- Variants: `*_AFTER`, `*_EXPLICIT(Signature, ...)` for overloaded functions, `UNSUBSCRIBE_METHOD` and `UNSUBSCRIBE_UOBJECT_METHOD`.
  - Warning: docs.ficsit.app names `SUBSCRIBE_METHOD_MANUAL` for overloads. In SML 3.12 only the `_EXPLICIT` variants exist (`NativeHookManager.h:589-658`). **[source]** (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Handlers**
- "Before": `void(TCallScope<Sig>& Scope, Class* Self, Args...)`. Static and free functions have no `Self`. For a `const` member function `Self` is `const Class*`, otherwise the handler does not compile **[source]** (`NativeHookManager.h:385`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
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
- **[source]** `Cancel()` and `Override(...)` also skip every later "before" handler of every mod: the chain goes on only while the call is forwarded (`bForwardCall`, `NativeHookManager.h:143-215`). "After" handlers always run. Another mod's `Cancel` can silently hide your "before" hook. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
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
- Methods of plain structs (not `UObject`s) can be hooked with `SUBSCRIBE_METHOD` without a sample object, including const methods returning an enum and methods returning a `TWeakPtr` by value. Verified on the railway signalling: `domains/railroad/signal-hooks.md`, "Hook targets in the railway signalling".
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
- Per-actor state: `UBlueprintActorMixin` (Actor Mixin).
  - **[source]** `bEnableMixinTick` defaults to false (`BlueprintHookingTypes.h:80-82`). The mixin's BeginPlay runs after the actor's, its EndPlay before. `Self` is the mixin; the actor is "Mixin Target". Find a mixin with `UBlueprintActorMixin::GetActorMixin(Actor, Class)`. Mixin hooks target the actor class chosen in the asset. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
  - **[?]** Docs only: mixins work only on Blueprint-implemented actors (not on drop pod loot), and `SaveGame` properties of mixin components on level actors are not loaded, so keep that data in a mod subsystem. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[source]** The old hook systems are dead in 3.12. C++ hooks on Blueprint functions (the `Bind on BPFunction` macros) were removed in 3.11, and `BlueprintSCSHooks` entries "no longer do anything" (`GameInstanceModule.h:76-81`, `DeprecatedLegacyHookingTypes.h`). A mod ported from older SML loses them silently; Actor Mixins replace the SCS hooks. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[?]** Blueprint hook assets, docs only: the implementation function cannot use latent nodes; a registered hook cannot be unregistered, so gate it on a flag; parameters map to the hook function's variables by exact name, and `By Ref` lets the hook modify them; a `bool ReturnValue` set to False cancels the rest of the function; hooks of UI Blueprints belong in `ClientBlueprintHooks`, or they error on a dedicated server. `-DumpBlueprintPatchingResults` as a launch argument prints the patched bytecode (the switch is read in `BlueprintHookManager.cpp:368`, **[source]**). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
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
