# Coroutines (UE5Coro) and compiler pitfalls

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML, game or engine code, not tested, **[?]** = uncertain. Split out of `references/patterns-and-pitfalls.md`; the numbered patterns and pitfalls stay there.

## Coroutines (UE5Coro) and splitting work across frames

You can include UE5Coro in the mod as source. It requires C++20.
- `UE5Coro::TCoroutine<>` + the last parameter `FForceLatentCoroutine = {}` (latent mode, ticks together with the world).
- Time budget: `UE5Coro::Latent::FTickTimeBudget::Milliseconds(n)`. Create it **outside** the loop.
  - `await_ready()` returns true as long as you are within the budget, and you can call it many times.
  - `await_resume` resets the clock.
- `Latent::NextTick()`, `Latent::AsyncLoadObject(SoftPtr)`.
- Critical section that must not be cancelled: `UE5Coro::FCancellationGuard`. Cleanup: `ON_SCOPE_EXIT`. Control: `Cancel()`, `IsDone()`.
- Note from pitfall 11 above: a coroutine starts synchronously.
- Work split across frames with a "the frame's first step always goes" rule (so a frame with no time left still makes progress) hangs when a bookkeeping checkpoint takes that first step. A <Mod> planner look added a budget check between two pairs of a list; the check ran before any real work of the frame, counted as the first step, so every real step after it (a list build, a route query) was refused as over budget. A caller that loops `while (!Step())` until the work is done then never finishes: the packaged game's self-test hung in a load until the run hit its timeout. What fixes it: a checkpoint refuses once the frame already did a real step (`if (StepsThisFrame > 0 && !MayGoOn())`). A self-test that drives the sliced work to the end with a zero budget per frame finishes in a bounded number of calls when the rule holds. Evidence: <scenario> self-test timeout on the build with the checkpoint, PASS with 0 failed checks after the fix. (2026-11-14, game 517554, SML 3.12.0)
- **A bounded sweep over a large `TMap` across frames walks its sparse indices, not an iterator.** A cursor runs `0 .. Map.GetMaxIndex()`: `FSetElementId::FromInteger(Cursor)`, skip `!Map.IsValidId(Id)`, read `Map.Get(Id)`, drop a stale entry with `Map.Remove(Id)`. Removal by id frees the slot without compacting or rehashing, so `GetMaxIndex` and the cursor stay valid between frames, and a `Reset()` is caught by wrapping the cursor when it passes `GetMaxIndex()`. The budget counts the entries removed, not looked at: each removal frees what the value owns (here a route with arrays), and 512 slots a frame took 0.18-0.19 ms while thousands of stale entries were being dropped, 128 slots at most 0.08 ms in the longest steps of the next 10 runs. Evidence: <scenario> frame-part lines of a planner's first step before and after the change, 10 runs each. (2026-11-15, game 517554, SML 3.12.0)

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

## Compiler pitfalls (MSVC/UHT)

- UHT runs with `-WarningsAsErrors`.
- **Variable shadowing is a hard error:**
  - `C4456` (a local shadows a local), e.g. two `Resource` variables in one function,
  - `C4458` (a local shadows a class field).
  - also a parameter or local named like an inherited member: a parameter `Role` in an actor class shadows `AActor::Role` (`C4458`, the packaged build failed until it was renamed),
  - **[source]** `C4457` (a local shadows a function parameter) and `C4459` (a local shadows a global, for example a constant `Now` or `L` at namespace level) are errors the same way (MSVC documentation).
- **[source]** `C4130`: `Name == TEXT("…")` with a `const TCHAR*` compares addresses, and under warnings-as-errors it stops the build. Use `FCString::Strcmp(Name, TEXT("…")) == 0` or an `FString`. (2026-10-06, game 502094, SML 3.12.0)
- `C2440` on `FVector4f{ FVector3f{ FVector }, 1 }`: first build an `FVector P`, then `FVector4f{ float(P.X), float(P.Y), float(P.Z), 1 }`.
- `C2398` (narrowing `int64` → `int`): `FMath::CeilToInt(double)` returns int64, use `CeilToInt32` or `FloorToInt32`.
- `C2679` (no `operator<<` for `const T`): `FArchive <<` needs a non-const lvalue, and a captured `const` copy stays `const` even in a `mutable` lambda.
- **[source]** The name `FTrackGraph` is taken by a game struct (`FGRailroadSubsystem.h`). Custom track graph types must use a different name or a prefix.
- Cast `sizeof` explicitly, e.g. `W * static_cast<uint32>(sizeof(FColor))`.
- **Include the headers you use**, e.g. `RenderingThread.h`, `RHICommandList.h`, `RHIUtilities.h`, `TextureResource.h`, `Tasks/Task.h`, `Misc/FileHelper.h`, `HAL/FileManager.h`, `HAL/IConsoleManager.h`, `ImageUtils.h`, `Modules/ModuleManager.h`, `Hash/CityHash.h`, `Compression/OodleDataCompressionUtil.h`, `GlobalRenderResources.h`.

