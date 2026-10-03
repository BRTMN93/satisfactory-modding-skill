# Rendering to render targets and UI

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 13. Rendering to render targets and UI

This section helps if your mod draws something, e.g. a map, a chart or a preview.

**Graphics card memory**
- An 8192² RGBA8 render target takes 256 MB, or 341 MB with mipmaps, permanently.
- The 16K version takes 1 GB, or 1.33 GB with mipmaps. 16384 is the maximum texture dimension in D3D.

**Choose the texture size by how large it appears on screen**
- An 8K map at the maximum zoom in the game gives about 0.89 screen pixels per texture pixel, so it is never magnified.
- A smaller texture gets blurry when zoomed in. A larger one gives nothing in the game, because the extra detail disappears when downscaling. It pays off only when exporting to a file.
- A 4K version with an overlay drawn at screen resolution looked worse: thin lines disappeared, because downscaling the 8K texture acts as free smoothing.

**`BeginDrawCanvasToRenderTarget` has two flaws**
1. It gives you a canvas **shared by the whole world** (`World->GetCanvasForRenderingToTarget()`). If you hold it across many frames and someone else draws to a render target in the meantime, your end-of-draw is lost, the canvas leaks, and the other party's canvas is deleted.
2. The canvas works in `CDM_ImmediateDrawing` mode, so **every `DrawItem` is a separate GPU pass**. Thousands of elements meant 51 s of drawing for me instead of 3–7 s.

**Your own canvas** (the same thing the engine does, but on your object):
```cpp
FTextureRenderTargetResource* Res = RenderTarget->GameThread_GetRenderTargetResource();
FCanvas* Canvas = new FCanvas(Res, nullptr, GetWorld(), GetWorld()->GetFeatureLevel(), FCanvas::CDM_ImmediateDrawing);
ENQUEUE_RENDER_COMMAND(MyBeginDraw)([Res](FRHICommandListImmediate& RHICmdList) { Res->FlushDeferredResourceUpdate(RHICmdList); });
// ... drawing across many frames ...
Canvas->Flush_GameThread(); delete Canvas; Canvas = nullptr;
ENQUEUE_RENDER_COMMAND(MyEndDraw)([Res](FRHICommandListImmediate& RHICmdList) {
    if (!Res->GetRenderTargetTexture()->GetDesc().IsMultisample())
        TransitionAndCopyTexture(RHICmdList, Res->GetRenderTargetTexture(), Res->TextureRHI, {});  // #include "RHIUtilities.h"
});
// End of drawing refreshes only the top mip. Recompute the others separately (e.g. UpdateResourceImmediate(false)).
```

**Drawing in batches instead of `DrawItem`**
- Get a batch: `FBatchedElements& B = *Canvas->GetBatchedElements(FCanvas::ET_Triangle, nullptr, Texture, SE_BLEND_AlphaBlend);`.
- Add `B.AddVertexf(FVector4f{x, y, 0, 1}, FVector2f{u, v}, Color, FHitProxyId{})` and `B.AddTriangle(v0, v1, v2, Texture, SE_BLEND_AlphaBlend)`.
- Submit once per frame: `Canvas->Flush_GameThread()`.
- Positions are in render target pixels. `FVector` has double precision in UE 5.6, so build `FVector4f` from floats.
- Get the batch again for every element, because a texture change gives a new batch and this keeps the draw order. Do not hold references across flushes.
- **Turn lines into triangles too.** `FBatchedElements::Draw` draws lines before meshes, so mixing lines with rectangles breaks the order. A thick line in the engine is the hull of two squares with a side equal to the thickness, and its color is forced to A=1.
- Rotate rotated rectangles on the CPU: `FTranslationMatrix(-Pivot) * FRotationMatrix(Rot) * FTranslationMatrix(Pivot)`. Rotation through the canvas creates a separate batch for each rectangle.
- The limit is 65,535 vertices per mesh element (uint16 indexes). The engine opens a new element itself after you exceed it.
- White texture for fills: `GWhiteTexture` (`GlobalRenderResources.h`).

**Blend modes**
- `BLEND_Translucent` from the canvas is `SE_BLEND_AlphaBlend`: it writes RGBA, and the alpha accumulates.
- `SE_BLEND_Translucent` writes only RGB. The `UImage` widget in UMG uses the texture's alpha, so render targets shown in the UI need AlphaBlend.
- Clearing only a region: a rectangle over the whole render target in color (0,0,0,0) with `SE_BLEND_Opaque` and scissor enabled.

**Textures loaded during drawing.** A batch holds a raw `FTexture*`, and textures from a `TSoftObjectPtr` may be released. Call `Flush_GameThread()` **before** `co_await AsyncLoadObject(...)`.

**Reading back and uploading**
- Reading: `Res->ReadPixels(TArray<FColor>&)` waits for the GPU, which is acceptable e.g. when saving the game.
- Uploading: `ENQUEUE_RENDER_COMMAND` + `RHICmdList.UpdateTexture2D(Res->GetRenderTargetTexture(), 0, FUpdateTextureRegion2D{0,0,0,0,W,H}, W*4, Data)`, then `UpdateResourceImmediate(false)`, which recomputes the mips without clearing.
- `RTF_RGBA8` is `PF_B8G8R8A8` in memory, i.e. the bytes are in BGRA order.

**Export to PNG at any scale**
1. Temporary render target: `NewObject<UTextureRenderTarget2D>`. Copy `RenderTargetFormat`, `bForceLinearGamma` and `TargetGamma` from the original, set `ClearColor=Transparent`, call `InitAutoFormat`, then `UpdateResourceImmediate(true)`. Finish with `ReleaseResource()`.
2. Draw in chunks: a local `FCanvas`, `Clear`, `PushAbsoluteTransform(FTranslationMatrix(-Offset) * FScaleMatrix(Scale))`, drawing, flush, `TransitionAndCopyTexture`, `ReadPixels` and copying into a `TArray64<FColor>`.
3. PNG: `FImageUtils::PNGCompressImageArray(W, H, TArrayView64<const FColor>, TArray64<uint8>&)` in a background task. Load the `ImageWrapper` module beforehand on the game thread.
4. Result at 16K: a 3–4 s hitch in the game, about 2 GB of RAM temporarily, a 7.5 MB file (a lot of transparency compresses well).

**Injecting UI into game widgets from C++**
- `Cast<UWidgetBlueprintGeneratedClass>(Cls)->GetWidgetTreeArchetype()`, `FindWidget("...")`, `InsertChildAt`, `ConstructWidget`, copy the `UCanvasPanelSlot` layout.
- Guards: `RequiresCookedData()`, `FPlatformProperties::IsServerOnly()`, `FApp::CanEverRender()`, `IsNetMode(NM_Client)`.
- SML widget hooks do the same without touching the tree by hand, and work entirely from C++ (section 5 of `references/sml-api.md`). Verified on the station, signal and locomotive windows (2026-10-02, game 502094, SML 3.12.0).
- **A C++ widget without an asset:** a plain `UUserWidget` subclass builds its tree in `RebuildWidget()`: create `WidgetTree` if it is null, set `WidgetTree->RootWidget` once (`WidgetTree->ConstructWidget<UCheckBox>(...)` and so on), then call `Super::RebuildWidget()`. Inside a hooked window, `GetTypedOuter<UFGInteractWidget>()` returns the owning window, also through named slots.
- **Order of construction:** the hooked child's `NativeConstruct` runs before the window's own Blueprint `Construct`. Variables the window sets there (for example `mTrain` of the locomotive window) are read a tick later (`SetTimerForNextTick`) or when used.
- **A new window on every open:** `AFGHUD::OpenInteractUI` created a new window instance each time, so nothing carries over between objects, and the widget remembers nothing either. Read the shown state from the mod when the widget is constructed.
- **Do not change the widget's slot in `NativeConstruct`.** `UVerticalBoxSlot::SetSize` there crashed with `Assertion failed: WidgetPtr` in `TWidgetSlotWithAttributeSupport<…>::GetContainerWidget`, because `NativeConstruct` runs inside the parent's `BuildSlot` → `TakeWidget`, before the Slate slot holds the widget. Set slot properties on the class archetype once, right after registering the hook: `GetWidgetTreeArchetype()->FindWidget(NewWidgetName)->Slot`. Every window created later copies them. Example: `Fill` size with bottom alignment puts a row at the bottom of a column. (2026-10-03, game 502094, SML 3.12.0)
- **Text colour:** the first `UTextBlock` of a game window is often a dim label. Borrow the font from a game text, but set the colour yourself.
- **Opening a window from C++:** `AFGHUD::OpenInteractUI(WidgetClass, Object)` opens any interaction window. It lands on `UFGGameUI::GetInteractWidgetStack()`, and `UFGGameUI::PopWidget` closes it. `AFGBuildable::GetInteractWidgetClass()` is protected, so read `mInteractWidgetSoftClass` through reflection.
  - **[?]** The same call a few frames after a save had loaded crashed in `UE::MovieScene::FSequenceInstance::Start()` (null read, from `UUMGSequenceTickManager::TickWidgetAnimations`). 15 s later it worked in every following run. One crash, cause not proven: let the world settle first.
  - **[?]** A widget class loaded with `LoadSynchronous()` and kept only in a plain `TSubclassOf` in a non-UPROPERTY struct was unusable 15 s later. Keeping it in `TStrongObjectPtr<UClass>` fixed it. Whether the class or the target object went invalid was not logged.
- **Reading a game window's real structure:** the starter project has only stubs, so dump it in the packaged game. Archetype tree: `GetWidgetTreeArchetype()->RootWidget` walked through `UPanelWidget::GetChildAt`. Named slot content: `UUserWidget::GetSlotNames` + `GetContentForSlot`. Blueprint variables and functions: `TFieldIterator<FProperty>` and `TFieldIterator<UFunction>` with `EFieldIterationFlags::None` for each Blueprint class in the chain. Live tree: open the window with `OpenInteractUI` and walk `WidgetTree` of each nested `UUserWidget`.

**Game railway widgets** (dumped at runtime, game 502094, SML 3.12.0, 2026-10-02)
- All three windows are `Widget_UseableBase_C : UFGInteractWidget` and get their object in `UFGInteractWidget::mInteractObject` (public).
- `Content/FactoryGame/Buildable/Factory/Train/Station/Widget_TrainStationNew`, the class in the station's `mInteractWidgetSoftClass`.
  - Variable `RailroadStation`.
  - The frame `mTrainStationWindow` (`Widget_Window_DarkMode_C`) lists the header tabs in `mTabs`: an array of the Blueprint struct `FImageAndText`, with fields `Texture_4_…` (`UTexture*`) and `Text_5_…` (`FText`). It has two entries, station and timetable.
  - Each tab shows the panel with the same index among the children of `HorizontalBox_0` (not a variable) in the `mContent` named slot of `Widget_SlidingTabs`. The sliding tabs size the window to the shown panel (the station panel is 594 px wide).
  - The header click goes to `BndEvt__mTrainStationWindow_K2Node_ComponentBoundEvent_4_OnTabButtonClicked__DelegateSignature(int32 ButtonIndex)`.
  - The train list opens the locomotive window inside the station window (`mLocomotiveMenuContainer`).
  - Other variables: `mTrainList` and `mStationList` (vertical boxes), `Widget_SlidingTabs`. Correction of the earlier stub reading: `mTabs` is not the sliding tabs widget of this window but the tab list of its frame.
- `Content/FactoryGame/Buildable/Factory/Train/Signal/Widget_RailroadSignal`: variable `mSignal`. Content is in `VerticalBox_0` inside `CanvasPanel_1`, under the state text. Other variables: `mTopSignal`, `mBottomSignal`, `mDescriptionText`, `mDescriptonIcon` (spelled so), frame `Widget_Window_DarkMode`. `mCurrentStateLabel` is in the tree but is not a variable.
- `Content/FactoryGame/Buildable/Vehicle/Train/Locomotive/UI/Widget_Locomotive_Menu`: the class is in `AFGLocomotive::mLocomotiveMenuWidgetClass`, which is protected, so read it by reflection.
  - Variables `FGLocomotive` and `mTrain` (`AFGTrain`).
  - Left column `VerticalBox_0`, info block `VerticalBox_2`, timetable column `VerticalBox_1`. Frame `mWindow` with one `mTabs` entry.

**Adding a tab to the station window** (verified: clicks from a player, screenshots, 2026-10-03, game 502094, SML 3.12.0)
1. Append an `FImageAndText` entry to `mTabs` of `mTrainStationWindow` on the class archetype: `GetWidgetTreeArchetype()->FindWidget("mTrainStationWindow")`, `FScriptArrayHelper` on the `FArrayProperty`, fields found by name prefix `Text_` / `Texture_`.
2. Add the panel as a new child of `HorizontalBox_0` with a widget hook (`Direct_Any`).
3. The window's own header handler shows only its two panels and ignores a third index. Bind your own `UFUNCTION(int32)` to the frame's `OnTabButtonClicked` multicast delegate (`FMulticastDelegateProperty::AddDelegate(Delegate, Frame)`). In it, call the sliding tabs' Blueprint `SetActiveIndex(int32 Index, bool animate)` through `ProcessEvent`.
4. The header buttons have a fixed size (`mButtonSize` of `Widget_TabsContainer_C`, 220×36 here, with 494 px of room), so a third tab shows only its icon and two letters. The buttons are children of the container's `mContainer` canvas and exist about 0.1 s after construct. Setting each `UCanvasPanelSlot` position and size per window instance gives three tabs of 164 px, and the layout survives tab clicks.
5. Give the panel the width of the game's first panel (`GetDesiredSize().X`, 594 px). A fixed 600 px widened the whole window by 6 px whenever the tab was opened.
