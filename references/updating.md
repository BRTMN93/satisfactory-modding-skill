# Updating a mod to a new game or SML version

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML, game or engine code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own. This file is the end-to-end order of work when the game or SML moves on, and the traps a port from older code meets. Moving the starter project itself (clone, merge, Wwise upgrade) is in `references/setup.md`, "Starter project"; the header comparison is pitfall 16 in `references/patterns-and-pitfalls.md`.

## Procedure

- **a) Copy first.** Copy the game folder (a game cannot be rolled back), the old engine and the project before anything is updated. Two engines with the same version string share one registry value, because `SetupScripts\Register.bat:6` writes `reg add HKCU\Software\Epic Games\Unreal Engine\Builds /v 5.6.1-CSS`: run `Unregister.bat`, rename the old engine folder, edit the registry value and the `EngineAssociation` of the old project, then register the new engine **[source]**. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **b) Read before touching.** The SML update guide for each version on docs.ficsit.app lists the engine tag, the Wwise version and the clang version. Run `scripts/doctor.ps1` and compare `Source/FactoryGame/currentVersion.txt` with the game's changelist (`references/setup.md`, step 5).
- **c) Build the new starter project alone.** Clone or merge it (`references/setup.md`, step 5), move the other mods out of `Mods/`, regenerate the project files and build. **[?]** The docs say the editor offers to "port" the project; editing `EngineAssociation` avoids it.
- **d) Put the mod back.** **[?]** One broken mod can block packaging of every mod in the project (docs only); renaming its `.uplugin` to `.uplugin.disabled` and regenerating the project files hides it, see `references/tools.md`, "Hiding a plugin from the engine". Update the mod's dependencies first.
- **e) Compile loop.** Compile, fix the errors (AccessTransformers, renamed members, the build-settings traps below), open the editor, Alpakit SML, bump `GameVersion` and the SML `SemVersion` in the `.uplugin`, package, launch, read the log (`LogSatisfactoryModLoader`, `Fatal` lines).
- **f) Never save an asset that opens with a missing parent or reference.** **[?]** The docs say an asset saved while its parent or a reference is missing gets `None` written silently over the good value; discarding the change in git and fixing the cause avoids it, and the old project is the only place to read the old field values.
- **g) Test, then release.** Patch notes, a `SemVersion` that never goes down, a dependency range `^x.y.z`.
- **h) Try the published build on the new game first.** **[?]** Alpakit packs with `UnversionedCookedContent: false` (`Mods/Alpakit/Source/Alpakit.Automation/PackagePlugin.cs:115`) **[source]**, so a Blueprint-only mod may survive an update unchanged; a C++ mod will not, because headers and virtual function tables change (pitfall 16).

(2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app; steps marked [?] are from the docs only)

## Build settings V5

- **[source]** The starter project sets `DefaultBuildSettings = Latest`, which is V5 (`Source/FactoryShared.Target.cs:75`; `<UE-CSS>/Engine/Source/Programs/UnrealBuildTool/Configuration/TargetRules.cs:121-150`). Code ported from UE 5.3 or 5.4 meets three effects at once. V2: `bLegacyPublicIncludePaths=false`, so an include needs its sub-path (`Hologram/FGHologram.h`, not `FGHologram.h`). V4: C++20 is the default, with strict conformance. V5: `bValidateFormatStrings=true` (`ModuleRules.cs:856-858`), so a `UE_LOG` or `Printf` with a wrong specifier (`%s` with an `FString` instead of `*FString`, `%d` with an `int64`) is a compile error. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## Core Redirects: renamed mods and moved assets without losing saved buildings

- **[source]** A mod's `Config/Engine.ini` with a `[CoreRedirects]` section holds the redirects. The file reaches the package only when `Config/PluginSettings.ini` carries an extra line `+AdditionalNonUSFDirectories=Config` next to the template's `+AdditionalNonUSFDirectories=Resources`: add it, because replacing the `Resources` line drops the mod icon (staging: `CopyBuildToStagingDirectory.Automation.cs:1518-1540`; a `[StageSettingsServer]` section exists for servers only).
- **[source]** A class redirect needs the `_C` suffix and no `Default__`; a package redirect looks like `+PackageRedirects=(OldName="/Old/...",NewName="/New/",MatchWildcard=true)`. docs.ficsit.app (CoreRedirect page) shows `MatchSubstring=true`; in UE 5.6 it still works but logs a deprecation warning (`CoreRedirects.cpp:2594`), and `MatchWildcard=true` with `...` in `OldName` is the form the engine's own config uses (`BaseEngine.ini:359-368`).
- **[source]** The engine reads a game feature mod's plugin ini and calls `ReadRedirectsFromIni` when the feature activates (`GameFeatureData.cpp:120,151,170`), and all loaded inis at start (`Obj.cpp:5534-5538`). **[?]** Which ini file name the plugin layer picks up was not verified. `-DebugCoreRedirects` on the command line shows what is applied.
- **[?]** A redirect becomes permanent in a game that is saved with it, so back up the saves first. For users the docs describe an `Engine.ini` in `<Game>\FactoryGame\Mods\SML\Config` that works too, to be removed after one save.
- (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## The UHT pointer setting

- **[source]** docs.ficsit.app (update guide 3.12) shows `[UnrealHeaderTool] NonEngineNativePointerMemberBehavior=Disallow` without saying in which file; see `references/patterns-and-pitfalls.md`, item 35. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## Game API changes seen in the 3.10 to 3.12 guides

All checked in the game headers **[source]**:
- `UFGRecipe::GetIngredients(const UObject* WorldContext, TSubclassOf<UFGRecipe>)` takes a world context (`FGRecipe.h:59`).
- `FChatMessageStruct::MessageText` is an `FText`, and the colour is `MessageSenderColor` (`FGChatManager.h:32,44`). `Usage` of a chat command, `UModConfiguration::DisplayName`/`Description` and `UConfigProperty::DisplayName`/`Tooltip` are `FText` too (`ChatCommandInstance.h:71`, `ModConfiguration.h:39,43`, `ConfigProperty.h:26,30`).
- Item descriptors, recipes, schematics and research trees have `mGameplayTags` (for example `FGRecipe.h:192`); the tag `Recipe.Part` exists (`Config/Tags/GameplayTags.ini:227`).
- `UFGChildInputMappingContext::mParentContext` (`Input/FGChildInputMappingContext.h:30`).
- **[?]** Assets the game used to find by themselves before 1.2 (user settings, messages, the icon library, input contexts) must now be listed under "Primary Asset Types to Scan" in the Game Feature Data asset; the docs say to copy the rules from a fresh "Blueprint Only" Alpakit template. Not checked in a built mod.
- (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

## AccessTransformers that seem to be ignored

- **[?]** After a line was added the compiler may still say "cannot access private member". See the AccessTransformers bullets in `references/mod-structure.md`; the working hypothesis there is that no timestamp is tracked, so touching any line of the ini (a `;` comment) or a full rebuild forces regeneration. Inconclusive when checked against the code. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
