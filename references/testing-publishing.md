# Testing, release, ficsit.app, working with someone else's mod

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 16. Testing and the pre-release checklist

**Rules**
- Test in the packaged game (rule 1 in `SKILL.md`).
- **Back up the saves before testing.** A copied save keeps its session name, so autosaves during testing overwrite the rotating slots of the *original* session. Rename the test session or turn autosave off.
- Launch parameters that change the resolution stay in the game's screen settings (`GameUserSettings.ini`), so the next normal start would open in the test window. Copy the file before the test and put it back after the game has closed (details under "Launching the game for tests").
- When measuring performance, record the conditions. Fullscreen and a borderless window give different results, and with frame generation the engine's frame times are not the same as the displayed frames.
- Manual tests: numbered steps, with a log-watching script confirming each step. Before saving the game, wait until the background work finishes.
- Automation: a separate test mod enabled by a launch parameter (e.g. `-MyModTestBridge`) reads commands from a file (`commands.jsonl`), loads saves, builds and dismantles buildings, samples frame times and memory, and writes the results to files. I picked this pattern up from another modder.
- Check rendering changes by comparing images pixel by pixel (old and new build, same save).

- **A test save built under another mod profile loses buildables when it is re-saved without those mods.** Track pieces and a conveyor lift were missing after a save was loaded and saved again in a profile with only SML. The save's session settings still carried the other profile's mod settings (`SessionSettings=...InfiniteZoop.BlueprintZoop=...` in `LogGameMode: ProcessServerTravel`). Build and change test saves only in the test profile, and after every change check them in the game, for example with one full lap of a test train. (2026-10-02, game 502094, SML 3.12.0)

**Launching the game for tests**
- **Starting the game straight into a save works** (docs.ficsit.app, Development → Testing). Launch `<Game>\FactoryGameSteam.exe` with:
  `-ini:Engine:[/Script/EngineSettings.GameMapsSettings]:GameDefaultMap=/Game/FactoryGame/Map/GameLevel01/Persistent_Level.Persistent_Level,[/Script/EngineSettings.GameMapsSettings]:LocalMapOptions=?skipOnboarding?listen?loadgame=<save name without path and extension>`
  - The argument has no spaces, so `Start-Process -ArgumentList @(...)` passes it unquoted.
  - The Steam client must be running.
  - **The Steam copy also needs `<Game>\Engine\Binaries\Win64\steam_appid.txt` containing `526870`.** Without it the log shows `LogSteamShared: Warning: SteamAPI failed to initialize, conditions not met.` and `LogOnlineServices: Game restarting within Steam client, exiting`. Steam then starts a second copy with only `-NO_EOS_OVERLAY`. That copy writes `FactoryGame_2.log`, because the first copy still holds the log. All your arguments are lost and the game sits in the main menu.
  - The root `FactoryGameSteam.exe` is a stub that stays alive next to `FactoryGameSteam-Win64-Shipping`.
  - On a 180 KB save it took 16–20 s from `Start-Process` to the world's BeginPlay.
  - Evidence: `LogInit: Command Line:` shows the arguments, then `LogGame: World Serialization (load)`.
  - **The local player does not get the character stored in the save.** It spawns somewhere else, and the stored character stays in the world as an idle pawn named "player". This was reported by the user from the packaged game. It is harmless for scenarios that do not need the player. Do not save the game from such a session, though, or the save gains a second player. **[?]** The cause has not been checked. The likely one is a different player identity than in a normal Steam start.
  - **The new player starts with empty player rules, so the advanced game setting "flight" is off** even when the saved player had it. Flight is a per-player rule (`FPlayerRules::FlightMode` in `FGPlayerState.h`). Calling `AFGPlayerState::SetFlightMode(true)` on the local player's state, once `UFGBlueprintFunctionLibrary::GetLocalPlayerController(World)->GetPawn()` exists, changed `GetPlayerRules().FlightMode` from 0 to 1 about one second after the world started. **[?]** That the character can then fly still needs a check in the game.
  - The loaded save's name can be read back with `FParse::Value(FCommandLine::Get(), TEXT("loadgame="), Name)`. The value stops at the space before the next argument. Useful for a test that saves again under the same name.
  - **[?]** Leaving such a session through the menu loaded the same save again (`LoadMap: ...?closed?skipOnboarding?listen?loadgame=<save>` right after the player saved and left). The likely cause is that the `-ini` override of `LocalMapOptions` also applies to the map the menu goes back to. Seen once.
- **A developer test mode behind a custom launch parameter works in Shipping.**
  - `FParse::Value(FCommandLine::Get(), TEXT("MyModTest="), Name)` reads `-MyModTest=<Name>`.
  - Start the scenario on the next tick after the world module's `POST_INITIALIZATION`.
  - Write steps and the result to the log under a fixed tag.
  - Close the game afterwards with `GLog->Flush()` and then `FPlatformMisc::RequestExit(false, TEXT("<call site>"))`. This logs `FPlatformMisc::RequestExit(0, <call site>)` and `Engine exit requested`, then shuts down cleanly (`LogExit: Exiting.`) in about 7 s.
  - A script that reads the log should move the old `FactoryGame.log` aside itself before the launch, so no line from an earlier run is mistaken for a result.
  - One cycle from launch to result took 22–24 s without packaging and 48–71 s with incremental packaging of an unchanged mod.
  - Scenarios that wait for the game, such as a train run, can end later from a timer or a delegate.
- A logic module that only compares game objects through weak-pointer handles can be self-tested in the packaged game without any game object: `NewObject<UObjectRedirector>(GetTransientPackage())` gives a real, distinct `UObject` per call (the class is exported from CoreUObject and concrete, `UObject` itself is abstract), so the test module needs only `Core` and `CoreUObject`. The objects are unreferenced, so keep the whole test inside one tick. Evidence: a self-test of 84 checks built this way passed in a Shipping build, started by a launch parameter after the world loaded. (2026-10-03, game 502094, SML 3.12.0, UE 5.6.1-CSS)
- **`-DisablePlugins=A,B` starts the game without the named mods and leaves their files alone.** The engine reads the parameter in Shipping builds too (`FPluginManager::ConfigureEnabledPlugins`, `<UE-CSS>/Engine/Source/Runtime/Projects/Private/PluginManager.cpp`). The log then says `LogPluginManager: Display: Skipping loading modules for <Mod>. Plugin is not enabled for current target.` and SML's list of loaded mods (`LogSatisfactoryModLoader: Display: <Mod>: <version>`) leaves the mod out. A test script can pass every `*.uplugin` name found under `FactoryGame\Mods` except SML and the mod under test, so a test run is not disturbed by whatever else is installed. Saves that were edited with two other mods installed loaded without them. (2026-10-03, game 502094, SML 3.12.0)
- **A small window cuts the GPU load of automated test runs by a third; the game stores the window arguments in the user's settings.**
  - `-windowed -ResX=640 -ResY=480` gives a window of 960×720 real pixels at 150 % display scaling. During the same train scenario the GPU board power fell from 43.4 W to 33.9 W on average (idle desktop 16–17 W, so about a third less above idle) and from 55 W to 40 W at the peak. The game's CPU use (2 cores) and frame rate (59 fps, capped at 60) did not change, and the scenario's result lines were the same.
  - Setting the scalability groups to 0 on top of the small window changed nothing measurable; the tester's settings already had most groups at 0.
  - The game rewrites `%LOCALAPPDATA%\FactoryGame\Saved\Config\Windows\GameUserSettings.ini` on every start. A run with `-ResX`/`-ResY` stored the test window there (`ResolutionSizeX/Y`, `LastUserConfirmedResolutionSizeX/Y`, `LastConfirmedFullscreenMode`), so the user's next normal start would have opened in the test window. Copy the file before the run and put it back after the game has closed; with that the file's SHA256 was the same before and after.
  - Quality values are stored twice in that file: in `[ScalabilityGroups]` and inside the `mIntValues=(("sg.…Quality", N),…)` line of `[/Script/FactoryGame.FGGameUserSettings]`. Values edited in both places before the start were kept by the game, except `sg.GlobalIlluminationQuality`, which it put back to 1.
  - (2026-10-03, game 502094, SML 3.12.0)
- **The game client cannot run without a renderer.** Started with `-nullrhi`, with only SML and the tested mod loaded, the packaged client loaded a save, ran the mod's first tick and died about 10 s later: `EXCEPTION_ACCESS_VIOLATION reading address 0x00000000000002e0` in the game's own `UFGTextRenderer::TickComponent` (`FGTextRenderer.cpp:54`) calling `UCanvas::K2_DrawText`. The frame counter moved only from 54 to 64 in those 10 s. So automated tests on the client need the renderer. **[?]** A dedicated server is the renderer-free target; it was not tried. A mod's own GPU code can also crash a client started with `-nullrhi`: see "A render target (any texture) has no resource when the game cannot render" in `references/rendering-ui.md`. (2026-10-03, game 502094, SML 3.12.0)
- **[source]** The documentation also gives a ready-made PowerShell script for launching the game (with, among others, the parameters `-loadLatestSave` and `-multiplayer`) and the parameters `-EpicPortal`, `-NoSteamClient`, `-log`, `-NewConsole`, `-nosplash`, `-windowed`, `-WaitForDebugger`. The syntax comes from a summary of the page, so it must be confirmed against the source. **[?]** Not tested yet, except `-windowed`, which worked together with `-ResX` and `-ResY` (above).
- **[source]** Testing with two clients locally: the host sets the session type to `IP`, the client types `open 127.0.0.1` in the console. Dedicated server locally: `FactoryServer.exe -log -EpicPortal -NoSteamClient`. Source as above (docs.ficsit.app, Development → Testing).

**Pre-release checklist**
- [ ] Package all the targets you release (Steam, EGS, Win/Linux servers).
- [ ] Small and large save; new game.
- [ ] 3 save loads in a row and a return to the menu: VRAM and RAM stable, no mod errors after loading, i.e. nothing leaks from the previous world.
- [ ] Multiplayer: host + client; dedicated server.
- [ ] Log without mod errors and warnings.
- [ ] `SemVersion` and `VersionName` bumped, `GameVersion` correct.
- [ ] Changelog with the numbers from your measurements and a list of what you did not test.

## 18. Publishing, ficsit.app, licenses, working with someone else's mod

### ficsit.app (SMR)
- **Before designing a mod, search ficsit.app through the API, not with a web search engine.** The web search engine did not find any of the existing railway mods, including a mod with 60 thousand downloads. The API found them at once. Search with several words from the domain (for example: train, station, logistic, dispatch).
- Search through the API. Several queries at once are separated by aliases (`a:`, `b:`):
  ```bash
  curl -s https://api.ficsit.app/v2/query -H "Content-Type: application/json" \
    -d '{"query":"{ a: getMods(filter: {search: \"train\", limit: 40, order_by: downloads, order: desc}) { mods { name mod_reference short_description downloads } } }"}'
  ```
- A `getModByReference` that returns `null` means the mod reference is free.
- The mod owner publishes releases.
- Each game branch (EA/EXP) has a compatibility state flag (e.g. `Works`, `Damaged`, `Broken`) and a note. The owner or the SMR moderators set it.
- Check a mod's state through the API:
  ```bash
  curl -s https://api.ficsit.app/v2/query -H "Content-Type: application/json" \
    -d '{"query":"{ getModByReference(modReference: \"<Ref>\") { name downloads compatibility { EA { state note } EXP { state note } } latestVersions { release { version } } authors { role user { username } } } }"}'
  ```
- **[?]** Whether the package on ficsit.app must contain DLLs for Steam and EGS and for the servers. Check docs.ficsit.app. Alpakit in release mode builds all targets.

### Licenses and forks
- Before forking or releasing someone else's mod, check the license: `gh api repos/O/R/license --jq .license.spdx_id`.
- GPL-3.0 allows releasing a fork, but you must keep the license, make the source available and credit the author.
- A fork is released under a **different mod reference**.
- First try to contact the author: an issue or PR, the Satisfactory Modding Discord, ficsit.app.

### Contributing to someone else's mod (GitHub)
- Reconnaissance: `gh issue list`, `gh pr list` and `view` with `-R o/r --json … --jq …`. Someone may have already fixed the same thing. If so, credit them in the description.
- Fork and PR:
  ```
  gh repo fork o/r --clone=false --default-branch-only
  git remote add fork <url>
  git push -u fork <branch>
  gh pr create -R o/r --base <default> --head <you>:<branch> --body-file description.md
  ```
  Mod repositories often have a default branch other than `master`.
- Send fixes and new features as separate PRs, and within a PR as separate commits, so that the author can reject a part.
- A PR that depends on a previous one targets the author's default branch and contains the previous one's commits. Write in the description "Stacked on #N, only the last commit is new".
- Mod repositories usually have no CI, so **test evidence goes into the PR description**: the engine tag, the game changelist, the build target, the save size, the measured numbers and what you did not test.
- Describe other people's findings that you carry over in the commit ("Thanks to X for finding this, see X/Repo@sha"). This does not make them co-authors.
