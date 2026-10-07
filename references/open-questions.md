# Uncertain / to verify

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Uncertain / to verify

- Requirements for a ficsit.app package: Steam and EGS, servers.
- Whether `-Target=` is an official `PackagePlugin` option. It worked for me.
- Whether generating Wwise soundbanks is ever needed.
- SMM's rules for removing mods: inferred from the `.smm` markers, without reading the ficsit-cli code.
- `SpawnLocal` + `bReplicates` + NetMulticast: it worked in one mod, the SML docs say otherwise.
- How an RCO gets registered without an entry in `RemoteCallObjects`. Registering explicitly is safer.
- Why an RCO needs an artificial replicated property (known only from a comment in SML).
- Whether the `mBuildableAdded/Removed` delegates fire on clients and for lightweight buildables.
- Verbose log levels in Shipping and changing verbosity on the fly (`[Core.Log]`): not tested.
- Unreal Insights, `stat` and profiling: not used.
- The engine assert `vLevel < NumMips` (VirtualTextureBuiltData.cpp) on the third load in a row: considered an engine bug, no proof.
- Raising the map zoom limit from a mod (the logic is in the `Widget_Map` Blueprint): not tried.
