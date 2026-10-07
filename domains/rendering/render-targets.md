# Rendering to render targets

Part of the `satisfactory-modding` skill, rendering domain (index: `domains/rendering/README.md`). Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

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
