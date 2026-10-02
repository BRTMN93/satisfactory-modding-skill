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

**What to do in which phase**
- `CONSTRUCTION`: your own state and subsystems. The instance config is not registered yet.
- `INITIALIZATION`: content registration, reading the config.
- `POST_INITIALIZATION`: things that depend on other mods, installing hooks.

**Arrays filled in the root Blueprint**
- Instance module: `ModConfigurations`, `BlueprintHooks`, `ClientBlueprintHooks`, `WidgetBlueprintHooks`, `GlobalItemTooltipProviders`, `GameMaps`, `SessionSettings`, `RemoteCallObjects`. On a dedicated server the "Client" ones are skipped.
- World module: `ModSubsystems` (spawned in `CONSTRUCTION`), `mSchematics`, `mResearchTrees`, `mChatCommands`, resource sink point tables, `mContentTagAdditionsTable`.

**Root pattern**
- A C++ class **without** `bRootModule` + a Blueprint child `RootInstance_<Mod>`, `RootGameWorld_<Mod>` or `RootMenuWorld_<Mod>` with `bRootModule = true`.
- Exactly one root of each type per mod, otherwise Fatal.
- Do not set `bRootModule` in the C++ class. The Blueprint child would inherit it and you would get two roots.
- The order of mods within a phase is undefined.

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
- In the editor, all Blueprint hooking is disabled.
- **Trap:** a hook on one path does not catch the others. Example: closing the map with its key bypasses `Widget_MapContainer::CloseMap`, so you also have to listen for the widget's destruction or hiding.
- You can find the names of the game's Blueprint functions and variables in the `.uasset` stubs from the starter project: extract strings matching `[\x20-\x7e]{5,}` from the bytes.

## 6. SML: config, subsystems, networking, commands, content, tools

### 6.1 Config
- **Creating:** a Blueprint child of `UModConfiguration` with `FConfigId{ModReference, Category}`.
  - Properties: `UConfigPropertyBool`, `Float`, `Integer`, `String`, `Class`, `Array`, `Section`.
  - Flags: `bRequiresWorldReload` only restricts the UI to the menu, `bHidden`, `bAllowUserReset`.
  - Registration through the `ModConfigurations` array, which happens in `INITIALIZATION`.
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

### 6.3 Networking: client ↔ server RPC (Remote Call Object)
- `UFGRemoteCallObject` with `Within=FGPlayerController`, one per player.
- Functions: `UFUNCTION(Server, Reliable)` from client to server and `UFUNCTION(Client, Reliable)` from the server to that one client.
- Every RCO needs a dummy replicated property and `GetLifetimeReplicatedProps`.
- Registration: `RemoteCallObjects` on the instance module. Getting it: `PC->GetRemoteCallObjectOfClass<T>()`.
- The server can check whether the client has a given mod: `USMLRemoteCallObject::IsClientModInstalled` and `GetClientModVersion`.

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
- Saving your own objects in the save: `IFGSaveInterface` + `UPROPERTY(SaveGame)`. Mod metadata: `UFGSaveSession::SetModMetadata` and `GetModMetadata` [source].
- SML console variables:
  - `SML.SkipModCompatibilityCheck`
  - `SML.ForceAllowCheats`
  - `SML.DumpBlueprintPatchingResults`
  - `SML.SkipRemoteModListCheck`
- The `-WaitForDebugger` parameter works in Shipping [source].
- Logs from Blueprints: `UBlueprintLoggingLibrary`, writes as `Log<ModRef>`.
