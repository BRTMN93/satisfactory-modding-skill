# SML: networking, commands and other useful things

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML, game or engine code, not tested, **[?]** = uncertain. Split out of `references/sml-config-networking.md`; config and subsystems stay there.

## SML: networking, commands, other

### Networking: client ↔ server RPC (Remote Call Object)
- `UFGRemoteCallObject` with `Within=FGPlayerController`, one per player.
- Functions: `UFUNCTION(Server, Reliable)` from client to server and `UFUNCTION(Client, Reliable)` from the server to that one client.
- Every RCO needs a dummy replicated property and `GetLifetimeReplicatedProps`.
- Registration: `RemoteCallObjects` on the instance module. Getting it: `PC->GetRemoteCallObjectOfClass<T>()`. Warning: docs.ficsit.app names `AFGPlayerController::GetRemoteCallObjectByClass` and `RegisterRemoteCallObjectOfClass`; in SML 3.12 / game 513885 they are `GetRemoteCallObjectOfClass` (`FGPlayerController.h:132`, template `:416`) and `RegisterRemoteCallObjectClass` (`FGPlayerController.h:135`, `FGGameMode.h:198`; also `RegisterCallObjectOnAllCurrentPlayers`, `:200`). **[source]** (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[source]** Registration details: `URemoteCallObjectRegistry::RegisterRemoteCallObject` is a public UFUNCTION; the module array calls it in `INITIALIZATION`, and every game mode init registers all of them again through `AFGGameMode::RegisterRemoteCallObjectClass` (`RemoteCallObjectRegistry.cpp:10-34`, `GameInstanceModule.cpp:96-99`). SML's own RCO has a `DummyReplicatedField` (`SMLRemoteCallObject.h:48`). An RCO class can also be found by the game feature scan (`UFGRemoteCallObject::GetPrimaryAssetId`; the virtual `ShouldRegisterRemoteCallObject(const AFGGameMode*)`, `FGRemoteCallObject.h:42-44`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[?]** Do not use `NetMulticast` in an RCO: it exists only on the server and the owning client (`Within=FGPlayerController`, `FGRemoteCallObject.h:13`), so a multicast reaches no other client (the class constraint is read in code, the crash docs describe is not tested). Use a replicated subsystem (`SpawnOnServer_Replicate`). For logic inside an RCO, see `references/multiplayer.md`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- The server can check whether the client has a given mod: `USMLRemoteCallObject::IsClientModInstalled` and `GetClientModVersion`.
- On a listen-server host, a `UFUNCTION(Server, Reliable)` of the local player's remote call object called from server code runs at once, inside the call: its log lines came in the same frame, before the next line of the caller. `PlayerController->GetRemoteCallObjectOfClass<T>()` returned the object about 1.5 s after the world started. Evidence: packaged-game log of 2026-10-03 20:21 UTC, frame counter `[  5]` on the call and on the server function's lines. (2026-10-03, game 502094, SML 3.12.0)
- **[source]** A server RPC parameter of type `TSubclassOf<UFGItemDescriptor>` arrives from the network as a plain `UClass*`: replication checks only that it is a class, not its base. A client can send any class, and `UFGItemDescriptor::GetForm(Class)` on a class that is not a descriptor reads the wrong CDO or trips `check`. The server-side check `Item && Item->IsChildOf(UFGItemDescriptor::StaticClass())` before any use closes it. From a code review; not tried with a modified client. (2026-10-08, game 502094, SML 3.12.0)

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

### Chat commands [source]
- Class: a subclass of `AChatCommandInstance`. In the constructor set `CommandName`, `Aliases`, `Usage`, `MinNumberOfArguments`, `bOnlyUsableByPlayer`.
- Logic: override `ExecuteCommand_Implementation(UCommandSender*, const TArray<FString>&, const FString&)`, which returns `EExecutionStatus`.
- Registration: `mChatCommands`, server only, or `AChatCommandSubsystem::Get(World)->RegisterCommand(ModRef, Class)`. Docs.ficsit.app confirms the class, the fields, `ExecuteCommand` and `mChatCommands` on the world module; `Usage` is an `FText` (`ChatCommandInstance.h:71`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **[source]** Helpers: `EExecutionStatus` is `COMPLETED`, `UNCOMPLETED`, `INSUFFICIENT_PERMISSIONS` or `BAD_ARGUMENTS`. `AChatCommandSubsystem::ParsePlayerName` accepts `@self`/`@s`, `@all`/`@a` or an exact player name (`ChatCommandLibrary.cpp:50-72`). Fewer arguments than `MinNumberOfArguments` prints the usage and does not call the command. (2026-10-24, game 513885, SML 3.12.0)
- **[source]** `SML.cfg` (in the `Configs` folder) has two options: `disabledChatCommands` (entries `<ModRef>:<CommandName>`; it blocks player senders only and answers `INSUFFICIENT_PERMISSIONS`; docs say the host's list applies to clients) and `enableFunchookLogging` (`SMLConfiguration.cpp:11-23`, `ChatCommandLibrary.cpp:76-78,143`). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

### Console commands
- `static FAutoConsoleCommandWithWorldArgsAndOutputDevice X(TEXT("MyMod.Cmd"), TEXT("description"), FConsoleCommandWithWorldArgsAndOutputDeviceDelegate::CreateLambda(...));` works in a Shipping build. Open the console with the `~` key.
- Write to the console through `Ar.Log` and `Ar.Logf`. `UE_LOG` entries at Display level also show up there.

### Other useful things from SML
- `UModLoadingLibrary`: `IsModLoaded`, `GetLoadedMods()` returns `TArray<FModInfo>` (good as part of a cache key), `GetModLoaderVersion`. **[source]** `FModInfo` has `Name, FriendlyName, Version, Description, CreatedBy, DocsURL, SupportURL, bRequiredOnRemote, RemoteVersionRange`; also `GetLoadedModInfo(Name, Out)` and `LoadModIconTexture` (`ModLoadingLibrary.h:20-66,100-125`). Warning: docs.ficsit.app says `GetLoadedMods` returns strings, `FModInfo` is `{ModId, Authors, Credits}` and the version call is `GetSMLVersion`; none of that matches SML 3.12. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- `UBlueprintAssetHelperLibrary::FindPluginNameByObjectPath`: which mod a given asset belongs to.
- `FReflectionHelper::GetPropertyValue`, `SetPropertyValue`, `CallScriptFunction`: access any property by name. Alternative in plain UE: `FindPropertyByName` + `ContainerPtrToValuePtr` and `CallFunctionByNameWithArguments`.
- Saving your own objects in the save: `IFGSaveInterface` + `UPROPERTY(SaveGame)`, tested on a subsystem ("Subsystems" above). Mod metadata: `UFGSaveSession::SetModMetadata` and `GetModMetadata` (the header format and the overwrite trap are under "Subsystems").
- SML console variables (all four exist: `SMLNetworkManager.cpp:15`, `BlueprintHookManager.cpp:184`, `SaveMetadataPatch.cpp:14`, `PlayerCheatManagerHandler.cpp:6`):
  - `SML.SkipModCompatibilityCheck`
  - `SML.ForceAllowCheats`
  - `SML.DumpBlueprintPatchingResults`: also works as the launch argument `-DumpBlueprintPatchingResults` (`BlueprintHookManager.cpp:368`)
  - `SML.SkipRemoteModListCheck`
- The `-WaitForDebugger` parameter works in Shipping [source]: `SatisfactoryModLoader.cpp:150-160` polls `IsDebuggerPresent` every 0.1 s in `PreInitializeModLoading` and then calls `DebugBreak()`, only `#if UE_BUILD_SHIPPING` (`:197`). Docs.ficsit.app (Cpp_debugging) says the same. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **Cheats in a test run:** `-ExecCmds="SML.ForceAllowCheats 1,EnableCheats"` gave the player controller a cheat manager (`SML.ForceAllowCheats = "true"`, `LogSatisfactoryModLoader: Warning: Cheats enabled via EnableCheats console command`); the hook calls `AddCheats(true)` (`PlayerCheatManagerHandler.cpp:13-25`). A cheat command itself was not run. `EnableCheats` alone, in a save without the session setting, is refused: `LogSatisfactoryModLoader: Error: Failed to enable cheats. Are you sure the Session Setting is enabled and that you are multiplayer host?` and no cheat manager. `SML.ForceAllowCheats` is a CVar and also a session setting stored per save (a save made in the game with it on has `?SessionSettings=SML.ForceAllowCheats=AgAAAAQAAAABAAAA,...` in its header, as docs say), but a save loaded through `?loadgame=` does not apply it: `EnableCheats` was refused the same way, CVar 0 ("Session Settings" below). **[?]** Docs list vanilla cheats to use afterwards: `PlayerFly true`, `NoPower true`, `NoCost`, `SetTimeSpeedMultiplier`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

- **[source]** `FVersion::ParseVersion` ends the game on a version number that does not fit its parser: `ParseVersionNumber` calls `std::stoul` (`SML/Private/Util/SemVersion.cpp:654-662`), `unsigned long` is 32-bit on Win64, the regex accepts any digit count, and a mod build has no exceptions, so `5000000000.0.0` terminates the process instead of returning the error text. A version string from a file or a config value passes only when it has three dot-separated parts of at most 9 digits. In the packaged game the checked path gives a warning and goes on with `'5000000000.0.0' is not a version`; the crash itself was read from the source, not reproduced. (2026-11-08, game 517554, SML 3.12.0)
