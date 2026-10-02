# Project and mod structure

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 3. Project and mod structure

**Plugins in the starter project** (the `Mods/` directory):
- `SML`: runtime.
- `SMLEditor`: Blueprint Hook and Mixin editors, "Generate C++ Config Struct Header", recipe editor and linter.
- `Alpakit`: mod wizard, packaging, copying to the game and launching.
- `AccessTransformers`: access to private members of the game.
- `WwisePatches`: Wwise patches, applied automatically at build (`references/setup.md`, 2.6).
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

**Several C++ modules in one mod**
- A game feature mod with several C++ modules packages and loads with no change to the procedure. Observed: a mod with five `Runtime` modules in phase `Default`, listed in `Modules` in the `.uplugin`. The skill's packaging script worked unchanged (4 min 09 s, game already compiled earlier).
- The zip has a separate DLL and PDB for each module (`FactoryGameSteam-<Module>-Win64-Shipping.dll`) and one shared `FactoryGameSteam-Win64-Shipping.modules`.
- In the game the modules load in the order of the `.uplugin`, all in the same millisecond, before `Version check passed` and before the SML mod list.
- The compiler enforces the boundary between modules. A module that does not have `FactoryGame` in its `Build.cs` dependencies cannot include a game header: `fatal error C1083: Cannot open include file: 'FGTrain.h': No such file or directory`. This can be used to enforce that pure logic does not depend on game classes. Such a module needs only the dependencies `Core` and `CoreUObject`.
- Shared log category: see "Logging in the mod" in `references/build-install-debug.md`.

**AccessTransformers** (`Config/AccessTransformers.ini`, section `[AccessTransformers]`) give access to private and protected members of the game:
- `Friend=(Class="AFoo", FriendClass="UBar")`
- `Accessor=(Class="AFoo", Property="mX")`: generates `GetmX()` and `SetmX()`.
- Editor only: `BlueprintReadWrite=(Class="/Script/FactoryGame.FGSchematic", Property="mUnlocks")`, `BlueprintCallable=(...)`, `BlueprintType=(Struct)`.

**Other config files**
- `Config/Alpakit.ini`: `[ModTargets] Targets=Windows|WindowsServer|LinuxServer`, that is, which targets to package for.
- Gameplay tags: `Config/Tags/*.ini`.

**Line endings and BOM:** in a repo with `core.autocrlf=true`, files in git have LF, and on disk they may have CRLF. Scripts that patch code must preserve the line ending style and the UTF-8 BOM. Read files as `utf-8-sig` and count bytes, because `grep -c $'\r'` in Git Bash can lie.
