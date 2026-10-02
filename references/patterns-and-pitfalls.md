# Patterns, pitfalls, coroutines, compiler

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 11. Patterns and pitfalls (lessons from real bugs)

1. **Global hook without a filter.** See section 5 (`references/sml-api.md`): put the filter on the first line and null the pointers.
2. **O(n²) in bulk loading.** Inserting sorted data still shifted the indexes on every element, which caused a 3-second freeze at 139k elements.
   - Sort once, build the indexes linearly and skip incremental fixes during initialization.
   - Split long loops with a time budget (section 12).
3. **Long work restarted on every change.** Every placed building cancelled the 51-second redraw, so it never finished while building.
   - Queue incremental changes behind the full work in progress. Only a new request for full work cancels the full work.
   - Merge series of events into one batch.
4. **Request-merging flag overwritten.** `PendingFull = bFull` lost a waiting full request. The correct form is `PendingFull |= bFull`.
5. **State leaks into the next world.** Objects that outlive the world, e.g. an instance module, carried tasks and queues over to the next load.
   - When the world closes, cancel the coroutines, empty the queues and reset the flags.
   - Null the static `Instance` in `BeginDestroy` and check it for null.
6. **Server crash.** The cause was `*TMap.Find()` without a check after a timeout had already removed the entry. On top of that, a timer fired on a destroyed object, `FBufferWriter` was used after a move, and there was a manual `FMemory::Free`.
   - Keep per-player state in that player's RCO, as a `TArray<uint8>` written by `FMemoryWriter`.
   - Never key state by a PlayerController sent by the client.
7. **There are no exceptions in UE.** `std::stoul` on a corrupted value kills the game. Use `LexFromString`, `ParseIntoArray`, `IsNumeric`, `FCString::Strtoui64`.
8. **Network data is untrusted.** Check counters (`if (Num < 0 || Num > Limit) Ar.SetError();`), stop after `Ar.IsError()`, and in `NetSerialize` set `bOutSuccess = !Ar.IsError()`.
9. **Uninitialized fields.** Initialize them in the class declaration.
10. **Parallel index structures** (e.g. a redirect from a quadtree to a data array): update them on **every** insert and delete, including elements you do not index. Otherwise the indexes drift apart by one.
11. **Coroutine handle overwritten.** A coroutine runs synchronously up to its first suspension, so a nested one started in the middle can be overwritten by the outer one's already finished handle. Store the handle only when `!IsDone()`.
12. **Shared engine resources.** `BeginDrawCanvasToRenderTarget` hands out the world canvas, shared by everyone. Holding it across many frames breaks drawing for you and for others. Make your own (section 13 (`references/rendering-ui.md`)).
13. **Cache keys.**
    - Compute them from the content: a rounded hash of the data used + settings + mod versions.
    - Do not base them on the date or file size, because autosaves rotate through slots and saves get copied.
    - The hash must cover everything that affects the result (I missed the spline shapes).
    - Do not write the cache while the state is changing. Use a "dirty" flag.
14. **Measure first, then optimize.** Logs with timings, the same save before and after the change. A single run is only a hint.
    - A single call timed with `FPlatformTime::Cycles64()` on Windows has a resolution of 0.1 µs: two back-to-back reads gave a 0 µs median and every single-call result was a multiple of 0.1 µs (**[?]** consistent with the usual 10 MHz QueryPerformanceCounter). Time a loop of thousands of calls for anything under a microsecond, and time single calls only for the cold-cache distribution.
15. **The game's `.cpp` files in the starter project are stubs with empty function bodies** (for example `void AFGTrain::TickSelfDriving(float dt){ }`). From the headers you can read what exists, but not how it works. Every assumption about the behaviour of native code needs a short experiment in the packaged game before code is built on it.
16. **The starter project's headers can be older than the installed game, and that has consequences.** Observed (headers 491125, game 502094, SML 3.12.0): the local `Source/FactoryGame/currentVersion.txt` said 491125, while the game is 502094. Comparing it with the game's changelist is described in section 2.5 (`references/setup.md`). Comparison with the current SML repository showed:
    - The `master` branch of the `satisfactorymodding/SatisfactoryModLoader` repository has the 502094 headers since commit `d2162c9` of 2026-08-12 ("Update headers to CL502094", 76 files). SML stayed at version 3.12.0 through this, and its public headers did not change. So the SML version alone does not tell whether the game headers are up to date.
    - 39 game headers changed. In `AFGBuildable`, 6 virtual functions were removed (the old set of build effects), 5 new ones were added, and 3 changed position. Derived classes, including the signal and the switch, now override `OnLegacyBuildEffectFinished` instead of `OnBuildEffectActorFinished`.
    - **[source]** Conclusion: a mod built on old headers has the wrong virtual function table layout for all buildables. Calling a virtual function, hooking a virtual function or a custom class derived from a buildable will land in the wrong place. Non-virtual functions are linked by name, so a mod that uses only those may keep working and notice nothing.
    - How to check in two minutes: compare `currentVersion.txt` with the game's changelist (`<Game>\Engine\Binaries\Win64\*.version`). The version in the repository is shown by `gh api "repos/satisfactorymodding/SatisfactoryModLoader/contents/Source/FactoryGame/currentVersion.txt" --jq .content | base64 -d`. The headers themselves can be fetched with a partial clone (`git clone --depth 1 --filter=blob:none --sparse`, then `git sparse-checkout set Source/FactoryGame/Public`) and compared with `diff -rq --strip-trailing-cr`.
    - This partly answers the skill's open question "which branch to take the starter project from": `master` follows the current game, and `currentVersion.txt` says which changelist the headers are for.
17. **The folder you work in does not have to be the project that is built.** Observed: sessions worked on a copy of the sources on the desktop (1 GB, without `Intermediate`, `Binaries` and Wwise), while building happened in a second copy on another drive. Before you record environment paths, check where `Binaries`, `Intermediate` and `Saved\ArchivedPlugins` are. The simplest setup is one copy that you work in.
18. **Before testing, check which mods are in the game installation.** Mods that interfere with the same area distort the results of experiments. Observed: the game had two mods that replace train routes and timetables. The list is given by the directories `<Game>\FactoryGame\Mods` and `<Game>\FactoryGame\Mods\GameFeatures`. Test in a separate SMM profile with SML only.

## 12. Coroutines (UE5Coro) and splitting work across frames

You can include UE5Coro in the mod as source. It requires C++20.
- `UE5Coro::TCoroutine<>` + the last parameter `FForceLatentCoroutine = {}` (latent mode, ticks together with the world).
- Time budget: `UE5Coro::Latent::FTickTimeBudget::Milliseconds(n)`. Create it **outside** the loop.
  - `await_ready()` returns true as long as you are within the budget, and you can call it many times.
  - `await_resume` resets the clock.
- `Latent::NextTick()`, `Latent::AsyncLoadObject(SoftPtr)`.
- Critical section that must not be cancelled: `UE5Coro::FCancellationGuard`. Cleanup: `ON_SCOPE_EXIT`. Control: `Cancel()`, `IsDone()`.
- Note from item 11.11: a coroutine starts synchronously.

```cpp
UE5Coro::TCoroutine<> UMyModule::ProcessAll(TArray<FItem> Items, FForceLatentCoroutine)
{
    ON_SCOPE_EXIT { OnFinishedOrCancelled(); };
    auto Budget = UE5Coro::Latent::FTickTimeBudget::Milliseconds(Config.TimeBudgetMs);
    for (const FItem& Item : Items)
    {
        DoWork(Item);
        if (!Budget.await_ready())     // the budget is used up
        {
            FlushPendingGpuWork();     // optional: submit what has been collected
            co_await Budget;           // finish in the next frame
        }
    }
}
```

**Background work:** `UE::Tasks::Launch(UE_SOURCE_LOCATION, [Data = MoveTemp(Data)] { ... })` works well for compression and file writes. Load modules only on the game thread (`FModuleManager::Get().LoadModule(...)`), before you start the task.

**Files**
- `FFileHelper::SaveArrayToFile` and `LoadFileToArray(..., FILEREAD_Silent)`, `IFileManager`.
- `FPaths::ProjectSavedDir()` is `%LOCALAPPDATA%\FactoryGame\Saved\`. `FPaths::ScreenShotDir()` is `...\Saved\Screenshots\Windows\`.

**Compression:** `FOodleCompressedArray::CompressTArray` and `DecompressToTArray` with Kraken and Fast compressed 256 MB to about 0.7 MB. Hash: `CityHash64WithSeed`.

## 15. Compiler pitfalls (MSVC/UHT)

- UHT runs with `-WarningsAsErrors`.
- **Variable shadowing is a hard error:**
  - `C4456` (a local shadows a local), e.g. two `Resource` variables in one function,
  - `C4458` (a local shadows a class field).
- `C2440` on `FVector4f{ FVector3f{ FVector }, 1 }`: first build an `FVector P`, then `FVector4f{ float(P.X), float(P.Y), float(P.Z), 1 }`.
- `C2398` (narrowing `int64` → `int`): `FMath::CeilToInt(double)` returns int64, use `CeilToInt32` or `FloorToInt32`.
- `C2679` (no `operator<<` for `const T`): `FArchive <<` needs a non-const lvalue, and a captured `const` copy stays `const` even in a `mutable` lambda.
- Cast `sizeof` explicitly, e.g. `W * static_cast<uint32>(sizeof(FColor))`.
- **Include the headers you use**, e.g. `RenderingThread.h`, `RHICommandList.h`, `RHIUtilities.h`, `TextureResource.h`, `Tasks/Task.h`, `Misc/FileHelper.h`, `HAL/FileManager.h`, `HAL/IConsoleManager.h`, `ImageUtils.h`, `Modules/ModuleManager.h`, `Hash/CityHash.h`, `Compression/OodleDataCompressionUtil.h`, `GlobalRenderResources.h`.
