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

**A render target (any texture) has no resource when the game cannot render.** That includes the normal client build started with `-nullrhi`.
- A mod that kept its GPU work behind `FPlatformProperties::IsServerOnly()` crashed the packaged game started with `-nullrhi`, in the first frame after a save was loaded, twice in a row: `RenderTarget->GameThread_GetRenderTargetResource()` returned null on the game thread, the null pointer was captured by an `ENQUEUE_RENDER_COMMAND` lambda, and the render thread died in `Resource->GetRenderTargetTexture()`. `IsServerOnly()` is a constant of the server build, so in the client build it is false whatever the command line says. The snippet above takes `Res` the same way and does not check it.
- **[source]** The engine creates a texture's resource only `if (FApp::CanEverRender() && …)` (`UTexture::UpdateResourceWithParams`, `<UE-CSS>/Engine/Source/Runtime/Engine/Private/Texture.cpp`), and `FApp::CanEverRender()` (`Misc/App.h`) is false on a dedicated server, in a commandlet and with `-nullrhi`.
- **[source]** The address in the crash, 0x50, is the offset of the `FRenderTarget` part inside `FTextureRenderTargetResource` in a Shipping build (its vtable pointer is read for the virtual call). So an access violation reading 0x50 on top of a render command points to a null render target resource, not to a null RHI texture inside it.
- **[source]** Skip GPU work (render commands, `ReadPixels`, your own `FCanvas`) when `FApp::CanEverRender()` is false, instead of when `IsServerOnly()` is true: under `UE_SERVER` it is a constant `false`, so the one check covers the dedicated server too. Not built or tested yet.
- **[source]** Engine functions that check the resource themselves and need no guard: `UKismetRenderingLibrary::ClearRenderTarget2D` and `UTextureRenderTarget2D::UpdateResourceImmediate` (both test `GetResource()`), and `FCanvas::Construct`, which accepts a null render target. `FRenderTarget::ReadPixels` and `FDeferredUpdateResource::FlushDeferredResourceUpdate` do not.
- The game itself does not run without a renderer either: with `-nullrhi` the packaged client died in its own code about 10 s after a load (`references/testing-publishing.md`, "Launching the game for tests").
- Evidence: `[frame 1] LogWindows: Error: Unhandled Exception: EXCEPTION_ACCESS_VIOLATION reading address 0x0000000000000050`, with the mod's render command lambda on top of the call stack, under `TGraphTask<TEnqueueUniqueRenderCommandType<…>>` and `RenderingThreadMain()`. (2026-10-03, game 502094, SML 3.12.0)

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
- **Checking a widget hook:** right after `RegisterWidgetBlueprintHook` the widget is already in the window class archetype (`GetWidgetTreeArchetype()->FindWidget(NewWidgetName)`), so this lookup is a start-up check that the hook got in. **[?]** The failing case (a parent panel that no longer exists) was not provoked; SML is expected to log its own error then.
- **A C++ widget without an asset:** a plain `UUserWidget` subclass builds its tree in `RebuildWidget()`: create `WidgetTree` if it is null, set `WidgetTree->RootWidget` once (`WidgetTree->ConstructWidget<UCheckBox>(...)` and so on), then call `Super::RebuildWidget()`. Inside a hooked window, `GetTypedOuter<UFGInteractWidget>()` returns the owning window, also through named slots.
- **Order of construction:** the hooked child's `NativeConstruct` runs before the window's own Blueprint `Construct`. Variables the window sets there (for example `mTrain` of the locomotive window) are read a tick later (`SetTimerForNextTick`) or when used.
- **A new window on every open:** `AFGHUD::OpenInteractUI` created a new window instance each time, so nothing carries over between objects, and the widget remembers nothing either. Read the shown state from the mod when the widget is constructed.
- **Do not change the widget's slot in `NativeConstruct`.** `UVerticalBoxSlot::SetSize` there crashed with `Assertion failed: WidgetPtr` in `TWidgetSlotWithAttributeSupport<…>::GetContainerWidget`, because `NativeConstruct` runs inside the parent's `BuildSlot` → `TakeWidget`, before the Slate slot holds the widget. Set slot properties on the class archetype once, right after registering the hook: `GetWidgetTreeArchetype()->FindWidget(NewWidgetName)->Slot`. Every window created later copies them. Example: `Fill` size with bottom alignment puts a row at the bottom of a column. (2026-10-03, game 502094, SML 3.12.0)
- **Text colour:** the first `UTextBlock` of a game window is often a dim label. Borrow the font from a game text, but set the colour yourself.
- `UComboBoxString::InitFont` and `InitForegroundColor` are `protected` in UE 5.6 (error C2248 from outside the class). The public `Font` and `ForegroundColor` fields are deprecated since 5.2 but still assignable; they are read only when the Slate widget is built, so set them right after `ConstructWidget` inside `PRAGMA_DISABLE_DEPRECATION_WARNINGS` / `PRAGMA_ENABLE_DEPRECATION_WARNINGS`. Style the rest with `SetWidgetStyle` (`ComboButtonStyle.ButtonStyle`, `MenuBorderBrush`) and `SetItemStyle` (`FTableRowStyle` row and selection brushes, text colours). A list built this way inside a game window showed the game's font and the chosen colours. Evidence: compile error, then screenshots of the packaged game. (2026-10-03, game 502094, SML 3.12.0, UE 5.6.1-CSS)
- **A searchable drop-down built from UMG parts** (the engine's `UComboBoxString` cannot narrow its options while typing): a `UButton` field (label plus a `UImage` with the combo style's `ComboButtonStyle.DownArrowImage`), and a `UScrollBox` of `UButton` rows on a `UOverlay` layer above the content, placed under the field from cached geometry (`ContentGeometry.AbsoluteToLocal(FieldGeometry.LocalToAbsolute(FVector2D(0, FieldSize.Y)))` as the overlay slot's padding, width = the field's local width). Make the owning `UUserWidget` focusable (`SetIsFocusable(true)`), call `SetKeyboardFocus()` when the list opens, and handle `NativeOnKeyChar` for the letters and `NativeOnKeyDown` for Enter, Backspace and Escape; return `Handled` for keys that carry a character while the list is open, so the game window's own keys (E closes it) do not fire. Typed letters reached the widget in a game window and narrowed the list (`'ir'` left 5 of 174 cargo names). Evidence: screenshots by the player, log `Cargo list: typed 'ir', 5 matches`. (2026-10-04, game 502094, SML 3.12.0, UE 5.6.1-CSS)
  - Traps seen on the way:
    - a `UOverlaySlot` aligns its child left by default, so the main column shrank to its content until set to `HAlign_Fill`,
    - a `UScrollBox` without a background lets the widgets below show through beside its scroll bar,
    - a scrolled `UScrollBox` draws a top shadow (`FScrollBoxStyle` `TopShadowBrush`) that made the list look a level below its field until set to `FSlateNoResource()`,
    - a `UButton` row keeps the `UButtonSlot` padding, so rows were taller than the game's drop-down rows until that padding was set.
- **Rebuilding a list inside its own event.** A combo box's `OnSelectionChanged` handler that clears and refills the options of that same box is a re-entrancy risk; redraw in the next frame (`SetTimerForNextTick`) instead. **[?]** Not provoked; the deferred redraw was used from the start.
- **Opening a window from C++:** `AFGHUD::OpenInteractUI(WidgetClass, Object)` opens any interaction window. It lands on `UFGGameUI::GetInteractWidgetStack()`, and `UFGGameUI::PopWidget` closes it. `AFGBuildable::GetInteractWidgetClass()` is protected, so read `mInteractWidgetSoftClass` through reflection.
  - **[?]** The same call a few frames after a save had loaded crashed in `UE::MovieScene::FSequenceInstance::Start()` (null read, from `UUMGSequenceTickManager::TickWidgetAnimations`). 15 s later it worked in every following run. One crash, cause not proven: let the world settle first. A later finding partly explains it: right after a load the game can sit in one long frame (see "A test that waits on the core ticker" in `testing-publishing.md`).
  - **[?]** A widget class loaded with `LoadSynchronous()` and kept only in a plain `TSubclassOf` in a non-UPROPERTY struct was unusable 15 s later. Keeping it in `TStrongObjectPtr<UClass>` fixed it. Whether the class or the target object went invalid was not logged.
- **The game's popup with a C++ content widget.** `UFGBlueprintFunctionLibrary::AddPopupWithContent(Controller, Title, Body, CloseDelegate, Content, EKeys::Invalid, PID_OK)` with a plain C++ subclass of `UFGPopupWidgetContent` (tree built in `RebuildWidget`) shows the popup (`Widget_Popup_C`) with the title and the content, but **not the Body text, and its Confirm button stays greyed**, so the player cannot close it. The popup asks the content `GetShouldOkayBeEnabled` (a `BlueprintImplementableEvent`) from Blueprint, which returns false without a Blueprint implementation; overriding `UObject::ProcessEvent` in the content does not catch that call.
  - What works: queue it with `PID_NONE` (no buttons) and an empty body, put the text and an own OK button into the content, and from that button call `mPopupWidget->CallPopupClosedClicked(true)` (`mPopupWidget` is set by the game), which fires the `FPopupClosed` delegate (`BindUFunction` on the content) with `true`, and then `UFGBlueprintFunctionLibrary::ClosePopup(PlayerController)`. A `PID_NONE` popup does not take itself off the screen after `CallPopupClosedClicked` (a player's click logged the delegate ten times while the popup stayed); `ClosePopup` removes it and `HasActivePopup` is false afterwards. Guard the delegate handler against running twice.
  - The engine's default `UCheckBox` images (with the tick) can be tinted through `FCheckBoxStyle` brushes' `TintColor`; replacing them with plain rounded brushes loses the tick. The popup then spans the screen width as a dark bar.
  - Evidence: screenshots of both variants; log `Inactive warning closed (OK 1), do not show again 1`; test check `the popup is gone after OK`; the player's clicks. (2026-10-04, game 502094, SML 3.12.0, UE 5.6.1-CSS)
- **Finding a hooked widget's window in a test.** The game's interact windows (locomotive window at least) are not `IsInViewport()`; they sit in a panel of the game UI. Look up the window as the widget's `GetTypedOuter<UFGInteractWidget>()` with `GetParent() != nullptr` (a closed window has left its panel). Evidence: lookup by `IsInViewport` found nothing, lookup by parent found the switch in every run. (2026-10-04, game 502094, SML 3.12.0)
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
  - **Add content on the canvas, not under the state text.** A widget hooked into `VerticalBox_0` of this window grows that box over the state label ("Block Clear" was covered). Hooked into `CanvasPanel_1` instead, with the archetype's `UCanvasPanelSlot` set once after registering the hook (anchors `(0,1,1,1)`, alignment `(0,1)`, offsets `(10,-10,10,0)`, auto size, z-order 10), it sits along the bottom of the window over the grille, and the state stays visible. Evidence: screenshots before and after. (2026-10-04, game 502094, SML 3.12.0)
- `Content/FactoryGame/Buildable/Vehicle/Train/Locomotive/UI/Widget_Locomotive_Menu`: the class is in `AFGLocomotive::mLocomotiveMenuWidgetClass`, which is protected, so read it by reflection.
  - Variables `FGLocomotive` and `mTrain` (`AFGTrain`).
  - Left column `VerticalBox_0`, info block `VerticalBox_2`, timetable column `VerticalBox_1`. Frame `mWindow` with one `mTabs` entry.
  - **A section like the game's own.** The section headings of `Widget_Locomotive_Menu` ("Status", "Info") are `BPW_TrainMenuLabel_C`. Take the class from the live window (`Window->WidgetTree->FindWidget("mInfoLabel")->GetClass()`), build it with `WidgetTree->ConstructWidget<UUserWidget>(Class)`, set its `mText` property and call its `SetText(FText)`, then `SetCollapsableWidget(UWidget*)` with the section body: the heading and its fold arrow look and work like the game's. A widget hooked into `VerticalBox_0` (left column) lands under "Info" and fits even at 640×480. Evidence: screenshots of the packaged game. (2026-10-04, game 502094, SML 3.12.0)

**Adding a tab to the station window** (verified: clicks from a player, screenshots, 2026-10-03, game 502094, SML 3.12.0)
1. Append an `FImageAndText` entry to `mTabs` of `mTrainStationWindow` on the class archetype: `GetWidgetTreeArchetype()->FindWidget("mTrainStationWindow")`, `FScriptArrayHelper` on the `FArrayProperty`, fields found by name prefix `Text_` / `Texture_`.
2. Add the panel as a new child of `HorizontalBox_0` with a widget hook (`Direct_Any`).
3. The window's own header handler shows only its two panels and ignores a third index. Bind your own `UFUNCTION(int32)` to the frame's `OnTabButtonClicked` multicast delegate (`FMulticastDelegateProperty::AddDelegate(Delegate, Frame)`). In it, call the sliding tabs' Blueprint `SetActiveIndex(int32 Index, bool animate)` through `ProcessEvent`.
4. The header buttons have a fixed size (`mButtonSize` of `Widget_TabsContainer_C`, 220×36 here, with 494 px of room), so a third tab shows only its icon and two letters. The buttons are children of the container's `mContainer` canvas and exist about 0.1 s after construct. Setting each `UCanvasPanelSlot` position and size per window instance gives three tabs of 164 px, and the layout survives tab clicks.
5. Give the panel both sizes of the game's first panel (`GetDesiredSize()`, 594 × 769 in the station window). A fixed 600 px widened the whole window by 6 px whenever the tab was opened. The window sizes itself to the shown panel, so a taller panel makes the window taller when its tab is shown. Setting the panel's `USizeBox` width and height to the first panel's `GetDesiredSize()` and scrolling the content inside kept the window the same width. Evidence: `window width 594.0 on the station tab, 594.0 on ours`. **[?]** The height was not measured, only seen on screenshots.
6. **Icon of the tab:** the `Texture_…` field of the `FImageAndText` entry in `mTabs` takes any game texture, for example `LoadObject<UTexture2D>(nullptr, TEXT("/Game/FactoryGame/Interface/UI/Assets/MonochromeIcons/TXUI_MIcon_Train.TXUI_MIcon_Train"))`, the game's monochrome train icon. It shows in the header like the game's own tab icons. The game uses that same texture in the locomotive window header (`mWindow.mTabs`); the station window's own tabs use `/Game/FactoryGame/Buildable/Factory/TrainStation/UI/TrainStation` and `/Game/FactoryGame/Buildable/Factory/Train/Station/UI/TXUI_Train_Icon_Timetable` (S6 dump of the archetypes). Evidence: screenshot of the station window, log `Station window: 3 header tabs, icon TXUI_MIcon_Train`.
7. **Switching tabs by keyboard:** the game's inputs "Activate Previous Tab" and "Activate Next Tab" of the tab container (`ActivatePreviousTab`) switch between the station window's tabs, including a tab a mod added. Arrow keys do not switch tabs in the game's windows; gamepad support was not tested.
8. **Other resolutions and UI scales:** the three-button header (164 units each in 494 of room) worked at UI scales 0.39, 0.44 (640×480 window), 0.89, 0.92 and 1.80. (game 502094, SML 3.12.0)
