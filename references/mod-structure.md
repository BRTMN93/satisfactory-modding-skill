# Project and mod structure

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Project and mod structure

**Plugins in the starter project** (the `Mods/` directory):
- `SML`: runtime.
- `SMLEditor`: Blueprint Hook and Mixin editors, "Generate C++ Config Struct Header", recipe editor and linter.
- `Alpakit`: mod wizard, packaging, copying to the game and launching.
- `AccessTransformers`: access to private members of the game.
- `WwisePatches`: Wwise patches, applied automatically at build (`references/setup.md`, "Project location first, then the Wwise integration").
- `GameFeatures/ExampleMod`: example mod.

**Where mods live:** `Mods/<Mod>` or `Mods/GameFeatures/<Mod>`.
- Alpakit creates game feature mods in `GameFeatures`, and packaging requires them to stay there (`PackagePlugin.cs:245-247`).
- A game feature mod needs a `UFGGameFeatureData` asset named like the plugin, in the root of `Content`.
- The `.uplugin` needs `"BuiltInInitialFeatureState": "Active"`.

**`.uplugin`: fields that SML reads** (`ModLoadingLibrary.cpp:24-100`):
- `SemVersion`: the mod version. On release, bump it together with `VersionName`.
- `GameVersion`: range of game changelists, e.g. `">=491125"`. The current value is in `Source/FactoryGame/currentVersion.txt`.
- `Plugins[].SemVersion`: required version of a dependency, e.g. SML `"^3.12.0"`. A mismatch of a dependency or of the game is Fatal outside the editor.
- `RequiredOnRemote`: `true` by default. `false` means a client-only or server-only mod.
- `RemoteVersionRange`: `>=SemVersion` by default.
- `FriendlyName`, `Description`, `CreatedBy`, `DocsURL`, `SupportURL`: shown in the mod list.
- A mod reference is the plugin name. Icon: `Resources/Icon128.png`.
- Version range syntax: `^ ~ >= <= < > =`, `1.2.x`, hyphen range (`SemVersion.h`).

```json
"SemVersion": "1.0.0", "VersionName": "1.0.0", "GameVersion": ">=491125", "RequiredOnRemote": true,
"Modules": [{ "Name": "MyMod", "Type": "Runtime", "LoadingPhase": "Default" }],
"Plugins": [{ "Name": "SML", "Enabled": true, "SemVersion": "^3.12.0" }]
```

**`Build.cs`**
- Start from `Mods/Alpakit/Templates/CPPAndBlueprintBlank/Source/PLUGIN_NAME/PLUGIN_NAME.Build.cs`.
- Set `CppStandard = CppStandardVersion.Cpp20` and `PCHUsage = UseExplicitOrSharedPCHs`.
- Public dependencies: Core, CoreUObject, Engine, DeveloperSettings, PhysicsCore, InputCore, GeometryCollectionEngine, AnimGraphRuntime, AssetRegistry, NavigationSystem, AIModule, GameplayTasks, SlateCore, Slate, UMG, RenderCore, CinematicCamera, Foliage, NetCore, GameplayTags, Json, JsonUtilities, DummyHeaders, **FactoryGame, SML**. For the Editor target, AnimGraph is added.
- Private dependency `RHI`, if you use RHI.
- Module: `IMPLEMENT_MODULE(FMyModModule, MyMod)`.
- A `PrivateDependencyModuleNames.Add("FactoryDedicatedClient")` in a mod's `Build.cs` (used only by test code that joins a dedicated server) made the mod's per-frame work measurably slower in the packaged game, with no code path of the hot loop touching that module. Evidence: the same synthetic load test (500 stations, 200 trains) gave the mod's longest per-frame step 1.22 to 1.53 ms with 35 to 37 of 60 steps over 1 ms on three builds with the dependency, and 0.71 to 1.15 ms with 0 to 2 of 60 over 1 ms on builds without it, including the same source with only the dependency (and the code using it) switched off. The cause is not known **[?]** (code layout or the module's load-time work). Test-only game-module dependencies can sit behind a `Build.cs` switch that is off in release builds, with the code that uses them under a matching definition (`PrivateDefinitions.Add("<MOD>_WITH_X=0")`, `#if <MOD>_WITH_X`). (2026-10-24, game 513885, SML 3.12.0)

**Several C++ modules in one mod**
- A game feature mod with several C++ modules packages and loads with no change to the procedure. Observed: a mod with five `Runtime` modules in phase `Default`, listed in `Modules` in the `.uplugin`. The skill's packaging script worked unchanged (4 min 09 s, game already compiled earlier).
- The zip has a separate DLL and PDB for each module (`FactoryGameSteam-<Module>-Win64-Shipping.dll`) and one shared `FactoryGameSteam-Win64-Shipping.modules`.
- In the game the modules load in the order of the `.uplugin`, all in the same millisecond, before `Version check passed` and before the SML mod list.
- The compiler enforces the boundary between modules. A module that does not have `FactoryGame` in its `Build.cs` dependencies cannot include a game header: `fatal error C1083: Cannot open include file: 'FGTrain.h': No such file or directory`. This can be used to enforce that pure logic does not depend on game classes. Such a module needs only the dependencies `Core` and `CoreUObject`.
- Shared log category: see "Logging in the mod" in `references/build-install-debug.md`.

**AccessTransformers** (`Config/AccessTransformers.ini`, section `[AccessTransformers]`) give access to private and protected members of the game:
- `Friend=(Class="AFoo", FriendClass="UBar")`
- `Accessor=(Class="AFoo", Property="mX")`: generates `GetmX()` and `SetmX()`.
  - Tested with `Accessor=(Class="AFGBuildableTrainPlatformCargo", Property="mFreightCargoType")`: `Class` takes the name with its `A`/`U` prefix, and the getter is a member, called as `Platform->GetmFreightCargoType()`.
  - Adding the line did not force a rebuild of the game module: the next Alpakit packaging took 166 s, about as long as one without the change.
  - For a `UPROPERTY` field that only needs reading, reflection works without AccessTransformers: `FindFProperty<FEnumProperty>(Class, TEXT("mX"))->ContainerPtrToValuePtr<void>(Object)`.
- Editor only: `BlueprintReadWrite=(Class="/Script/FactoryGame.FGSchematic", Property="mUnlocks")`, `BlueprintCallable=(...)`, `BlueprintType=(Struct)`.

**Other config files**
- `Config/Alpakit.ini`: `[ModTargets] Targets=Windows|WindowsServer|LinuxServer`, that is, which targets to package for.
- Gameplay tags: `Config/Tags/*.ini`.

**Line endings and BOM:** in a repo with `core.autocrlf=true`, files in git have LF, and on disk they may have CRLF. Scripts that patch code must preserve the line ending style and the UTF-8 BOM. Read files as `utf-8-sig` and count bytes, because `grep -c $'\r'` in Git Bash can lie.
