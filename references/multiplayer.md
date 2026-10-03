# Multiplayer and dedicated server

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 14. Multiplayer and dedicated server

**Who is who**
- Client: `GetWorld()->IsNetMode(NM_Client)`.
- Dedicated server: `FPlatformProperties::IsServerOnly()` or `IsRunningDedicatedServer()`. Wrap rendering code in `#if !UE_SERVER`.
  - `IsServerOnly()` is a constant of the server build, so it is false in the client build even when the client runs without a renderer (`-nullrhi`). **[source]** GPU work that also runs on the client should check `FApp::CanEverRender()` (`references/rendering-ui.md`, "A render target (any texture) has no resource when the game cannot render").
- Authority: `HasAuthority()`.

**The client does not have distant buildings**
- The server sends the client a snapshot through an RCO: the client asks through `Server`, the server answers through `Client` in chunks of about 2 KB so it does not clog the link.
- Send the request after `AFGHUD::CloseRespawnUI`, not in the PlayerController's BeginPlay, because packets get lost during joining.
- Incremental changes can be broadcast through `NetMulticast, Reliable` on the subsystem. **[?]** `SpawnLocal` + `bReplicates` worked in one mod, but the SML documentation says `SpawnLocal` does not replicate. Choose `SpawnOnServer_Replicate`.

**Serialization traps**
- Do not set `ArIsNetArchive` when serializing a large array into your own buffer, because it limits array sizes.
- `FBufferWriter` handles moving badly and ignores `FName`.

**Mod versions on players' machines**
- `RequiredOnRemote` and `RemoteVersionRange` are checked on join.
- Do not change the network data format or RPC signatures without need. That way the old and new version of the mod play together.

**Host-only features** (e.g. a cache) must skip clients and the dedicated server.

**Test on a dedicated server.** It is free on Steam and runs on the same computer. I did not do this in my project, so it is the first candidate for hidden bugs.
