# Uncertain / to verify

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Uncertain / to verify

- Requirements for a ficsit.app package: partly answered. ficsit.app keeps one archive per target (`Windows`, `WindowsServer`, `LinuxServer`), Steam and EGS are not separate targets (both DLL sets are in the `Windows` archive), and Alpakit Release builds all three from the profile's targets (`PackagePlugin.cs:126-158`, `Alpakit.cpp:224-236`). Still open: whether ficsit.app rejects a zip that lacks a target, or only marks the mod as server-incompatible. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- Whether `-Target=` is an official `PackagePlugin` option. It worked in practice.
- Whether generating Wwise soundbanks is ever needed. The docs say to generate them; in the verified setup the editor and packaging work without (`references/setup.md`, step 6). The docs' remark that the editor crashes later was not seen. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- SMM's rules for removing mods: inferred from the `.smm` markers, without reading the ficsit-cli code. The docs agree (SMM removes the files it placed, and tells the user to delete the `Mods` folder by hand if that fails); `.smm` markers exist on SMM-installed mods only. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- `SpawnLocal` + `bReplicates` + NetMulticast: it worked in one mod, the SML docs say otherwise.
- Why an RCO needs an artificial replicated property (known only from a comment in SML).
- Whether the `mBuildableAdded/Removed` delegates fire on clients and for lightweight buildables.
- **[source]** Verbose log levels in Shipping and changing verbosity on the fly: the docs (Logging) give `Engine.ini` `[Core.Log]` and the `-LogCmds` argument, and the engine reads both (`<UE-CSS>/Engine/Source/Runtime/Core/Private/Logging/LogSuppressionInterface.cpp:492-560`). Still untried in Shipping. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- Unreal Insights, `stat` and profiling: not used.
- The engine assert `vLevel < NumMips` (VirtualTextureBuiltData.cpp) on the third load in a row: considered an engine bug, no proof.
- Raising the map zoom limit from a mod (the logic is in the `Widget_Map` Blueprint): not tried.

## Answered

- How an RCO gets registered without an entry in `RemoteCallObjects`: `URemoteCallObjectRegistry::RegisterRemoteCallObject` registers it again on every game mode init (`RemoteCallObjectRegistry.cpp:10-34`). Details: `references/sml-config-networking.md`. (2026-10-24, game 513885, SML 3.12.0)
