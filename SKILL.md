---
name: satisfactory-modding
description: Knowledge and procedures for creating, fixing, building, testing and releasing Satisfactory 1.x mods (Unreal Engine 5.6.1-CSS + Satisfactory Mod Loader SML 3.12, C++ and Blueprints). Covers the environment (CSS engine, Wwise, starter project), mod structure (.uplugin, Build.cs, GameFeatures), SML modules and hooks, config, RPC and multiplayer, packaging (Alpakit, RunUAT PackagePlugin), installing into the game and SMM, FactoryGame.log, crashes, VRAM measurement, performance, rendering to render targets, testing and publishing on ficsit.app. The skill learns: it records new findings and corrections while you work and can send them upstream as a pull request. Use it whenever the user works on a Satisfactory mod (their own or someone else's), mentions SML, FactoryGame, Alpakit, ficsit, SMM, AFGBuildable or lightweight buildables, or builds, installs or debugs a mod for this game, even if they do not ask for the skill by name.
---

# Satisfactory modding

Verified on: game 1.x (changelist 502094), UE 5.6.1-CSS (tag `5.6.1-css-83`), SML 3.12.0, Windows, Steam. The knowledge comes from work on real C++ mods (fixes, performance, pull requests to mod authors) and from reading the SML code and the game headers.

## Symptom index

| Symptom | Look first |
|---|---|
| Crash at start or while loading a save | `CrashContext.runtime-xml` ("Diagnosis" below); two root modules (rule 2); a hook without a filter (rule 3) |
| The mod is missing from the mod list | `LogSatisfactoryModLoader: Display: <Mod>` in the log; the install folder (rule 8); `GameVersion` and the SML dependency in `.uplugin` (`references/mod-structure.md`) |
| C++ works, assets or Blueprints are missing | `LogPakFile: Mounted Pak file` for the mod; the install folder (rule 8) |
| A hook or a change has no effect | tested in the editor (rule 1); `Successfully hooked` in the log; hooks installed in `POST_INITIALIZATION` (rule 3) |
| Installing fails: "Permission denied", "Close the game first" | the game still runs or hangs on exit (`references/testing.md`, "A game that hangs on exit") |
| The self-built mod is gone or replaced | SMM or a game update (rule 13; `references/build-install-debug.md`, "Adding the same mod in SMM overwrites your version") |
| A game started by a script sits in the menu, the log is `FactoryGame_2.log` | `steam_appid.txt` (`references/testing.md`, "Launching the game for tests") |
| Compile errors `C4456`/`C4458`, unknown game classes or members | rule 9; the headers' changelist against the game's (`scripts/doctor.ps1`) |
| Memory or VRAM grows, hitches | rules 3, 5, 6 and 10; `scripts/vram.ps1` |

## How to use

This file holds the rules and procedures needed in almost every modding task. Read the details in `references/` only when the topic comes up:

| Topic | File |
|---|---|
| Setting up the environment from scratch | `references/setup.md` |
| `.uplugin`, `Build.cs`, GameFeatures, AccessTransformers | `references/mod-structure.md` |
| Modules, lifecycle, hooks, config, subsystems, RCO, commands, content registration | `references/sml-api.md` |
| Buildables (actors and lightweight), factories, saves, managers, map | `references/game-classes.md` |
| Packaging, installing, SMM, logs, crashes, VRAM | `references/build-install-debug.md` |
| Lessons from mistakes, UE5Coro coroutines, compiler errors | `references/patterns-and-pitfalls.md` |
| UI injection into game windows, widget hooks from C++, popups, searchable lists | `references/ui.md` |
| Client, dedicated server, RPC, version compatibility | `references/multiplayer.md` |
| Tests, launching the game into a save, test mode, release checklist | `references/testing.md` |
| Automated test runs: watchers (`scripts/watch-run.sh`), series, sub-agents | `references/test-automation.md` |
| ficsit.app, licences, pull requests to other people's mods | `references/publishing.md` |
| Scripts and tricks (git, Oodle, names inside assets) | `references/tools.md` |
| Open questions | `references/open-questions.md` |
| Recording findings, the inboxes, folding them in, privacy check | `references/learning.md` |
| Pull requests to this skill, updating from upstream, merging contributions (maintainer) | `references/upstream.md` |

**Domains.** A topic that only some mods need lives in its own folder `domains/<name>/`, not in `references/`. Open a domain's files only when the task touches its topic: a mod about something else never reads them, so they cost it nothing. Start with the domain's index `domains/<name>/README.md`, which names the file for each topic, and open only that file. Which category a fact belongs to is decided in `references/learning.md`, section 1.

| Domain | Folder | Open it when the mod deals with |
|---|---|---|
| railroad | `domains/railroad/` | trains, timetables, stations, platforms, tracks, signals, blocks, routes |
| rendering | `domains/rendering/` | drawing into textures: render targets, FCanvas, batches, PNG export (maps, charts, previews) |

`learned/findings.md` holds the core findings that are not folded into the references yet, and `learned/<domain>.md` those of a domain. Check the core inbox and the inbox of every domain the task touches, when a topic comes up.

Markers in the files: no marker = verified in practice, **[source]** = read from SML or game code but not tested, **[?]** = uncertain. Before you build code on **[source]** or **[?]**, check it in the code (`Mods/SML/Source/SML`, `Source/FactoryGame/Public`, `<UE-CSS>/Engine/Source`) or on https://docs.ficsit.app. A quick way: find the same API used in SML, the game or another mod that already compiles.

If `local/user.md` exists in this skill's folder, read it at the start. It holds the user's personal conventions (git identity, authorship rules, paths) and overrides the generic advice here.

- **Environment and versions:** at the start of a modding task run `scripts/doctor.ps1` once (the first time with `-Project <folder with FactoryGame.uproject>`). It finds the game, the CSS engine, SML and the starter project's headers, writes them to `local/env.md` and warns when they differ from the "Verified on" line above; then re-check the statements the task depends on (`references/learning.md`, section 2).
- **Language:** answer in the language the user writes to you in. Code, comments, commit messages, pull request texts and the files of this skill are always English.
- **Git identity:** when a commit or pull request is first needed under the user's name and `local/user.md` has no git identity, ask once whether to link the work to their GitHub account (login and e-mail) and save the answer in `local/user.md`. Do not take the identity from the global git config without asking.
- **The skill stays general:** it holds facts about the game, SML and the engine, never one user's project. A project only feeds it findings.

## Rules that prevent the most common mistakes

1. **Test in the packaged game.** In the starter project the editor does not load SML modules and does not apply patches, so a test in the editor proves nothing.
2. **Always call `Super` in `DispatchLifecycleEvent`.** That is where SML registers configs, Blueprint hooks and RCOs from the module's arrays.
   - The root is a Blueprint child (`RootInstance_<Mod>`, `RootGameWorld_<Mod>`) with `bRootModule` ticked.
   - The C++ class does not set this flag. Otherwise the child inherits it, two roots appear and the game stops with a Fatal error.
3. **A hook fires for every instance in every world.**
   - The first line of the handler filters to your object and lets everything else through via `Scope(...)`. A global hook without a filter once took 16 GB of VRAM from the game.
   - Install hooks in `POST_INITIALIZATION`, inside `if (!WITH_EDITOR)`.
   - In "after" hooks of functions with a return value, the result is the first argument.
4. **Buildables are actors and lightweight.** Foundations, walls and similar are not actors but data in `AFGLightweightBuildableSubsystem`. Code that looks only at `GetAllBuildablesRef()` misses most buildables.
5. **Clean up when the world closes.** The instance module outlives the world and carries coroutines, queues and flags into the next load. `OnWorldBeginTearDown` fires twice (menu world and transition world), so check `World == GetWorld()`.
6. **Split long work across frames and do not restart it on every change.**
   - A time budget (`FTickTimeBudget`) in the loop.
   - Queue incremental changes behind a running full pass.
   - Batch bursts of events: placing a blueprint fires about 300 hooks.
   - Avoid O(n²) during mass loading.
   - Expose the time budgets in the mod's config.
7. **UE has no exceptions, and network data is untrusted.**
   - Parse with `LexFromString` or `ParseIntoArray`, because `std::stoul` on a broken value kills the game.
   - Check the result of `TMap::Find` and counters read from an archive.
   - Keep per-player state in that player's RCO.
8. **Install with the game closed and into the right folder.** A game feature mod goes to `FactoryGame\Mods\GameFeatures\<Mod>`. In the wrong folder the C++ runs but the asset paks do not mount.
9. **Shadowed names are compile errors** (`C4456`, `C4458`, because UHT runs with `-WarningsAsErrors`). Packaging takes minutes, so group changes before a build.
10. **Measure instead of guessing.** Log the duration of work phases, measure the VRAM of the game process alone (`scripts/vram.ps1`) and do the three-loads test: load the save three times in a row, returning to the menu in between. One run is a hint, not a statistic.
11. **Back up the saves before testing.** A copy of a save keeps the session name, so autosaves during tests overwrite the original's slots.
12. **Multiplayer:** the client (`IsNetMode(NM_Client)`) and the dedicated server (`FPlatformProperties::IsServerOnly()`) can do different things than the host. Do not change the RPC format without need; then different mod versions can play together.
13. **Keep a backup of a working build outside the game folder,** with a note on how to restore it. A game or SMM update can remove or disable a self-built mod.

## Procedures

### New mod
1. Prepare the environment following `references/setup.md`. This is done once per computer.
2. In the CSS editor open `FactoryGame.uproject` and click **Alpakit Dev** on the toolbar (the alpaca icon after the Play group, next to **Platforms**; also in the **File** menu), then **Create Mod**. The templates **Blueprint Only** and **C++ & Blueprint** create a game feature mod in `Mods/GameFeatures/<Mod>`. The plugin name is the mod reference and cannot be changed later. The editor details are in `references/setup.md`.
3. Fill in `.uplugin` (`SemVersion`, `VersionName`, `GameVersion`, SML dependency `^3.12.0`) and `Build.cs` (Cpp20, FactoryGame and SML dependencies) following `references/mod-structure.md`.
4. Write the C++ module with a Blueprint root and split the code into lifecycle phases following `references/sml-api.md`.
5. Package, install, start the game and check the log (below).

### Building and installing
The script does both:
```powershell
& "<skill>\scripts\package-and-install.ps1" -EngineDir <UE-CSS> -Project <Project>\FactoryGame.uproject -Mod <Mod> -GameDir <Satisfactory game folder>
```
- Without `-GameDir` it only packages.
- `-Target ''` builds both targets, Steam and EGS. By default it builds Steam only, which is enough for local tests.

A repeat packaging run where only the mod changed takes 1.3–5 min. The first one takes about 47 min.

The manual command, the zip layout and the details are in `references/build-install-debug.md`.

### Diagnosis
- **Log:** `%LOCALAPPDATA%\FactoryGame\Saved\Logs\FactoryGame.log`. Times are UTC, and the game renames the old log on every start. Live: `scripts/watch-log.ps1 -Pattern 'LogMyMod|LogSatisfactoryModLoader|Fatal error'`.
- **Is the mod working:**
  - `LogSatisfactoryModLoader: Display: <Mod>: <version>`: the mod loaded,
  - `LogNativeHookManager: … Successfully hooked`: the hooks are installed,
  - `LogPakFile: Mounted Pak file`: the paks are mounted.
- **Crash:** `%LOCALAPPDATA%\FactoryGame\Saved\Crashes\UECC-Windows-*\CrashContext.runtime-xml`, with `ErrorMessage` and `CallStack` inside.
- **Hitches:** many log lines with the same frame number (second bracket) spread over seconds.
- **More:** `references/build-install-debug.md`.

### Before a release
Go through the checklist in `references/testing.md`:
- every build target you release,
- a small and a large save,
- 3 loads of the save and a return to the menu,
- host with a client and a dedicated server,
- a clean log,
- bumped versions,
- release notes with numbers from measurements.

### Working on someone else's mod
Check the licence before you fork. Send changes as separate pull requests and put the test evidence in the description. Push, open a pull request or comment on GitHub only after the user explicitly agrees. Details: `references/publishing.md` and `references/tools.md`.

## The skill learns

The game, SML and the engine change, and this skill only stays useful if what each session discovers flows back into it. Full procedure: `references/learning.md`.

- **While you work:** as soon as you establish something the skill does not have, find that the skill is wrong, or test a **[source]**/**[?]** claim, add an entry to the inbox of its category (core: `learned/findings.md`, a domain: `learned/<domain>.md`, see `references/learning.md`, section 1) with its marker, evidence, date and versions. Tell the user in one line. Search the skill first so you do not duplicate it. Leave out project decisions and anything personal.
- **When a modding task is done:** if 5 or more entries are waiting, or a correction of an unmarked statement, or an entry that prevents a crash or data loss, ask the user once: fold the findings into the skill, fold them and open a pull request to the skill's upstream repository, or not now.
- **Updating:** at the start of a modding task, once per session, offer in one line to check the upstream for a newer skill (details and when: `references/upstream.md`, section 2). An update commits the local state first and then merges; it never overwrites local knowledge that the upstream lacks, and it ends with a list of what only this copy knows, offered as a pull request.
- **Maintainer:** the repository's owner can ask to merge the users' pull requests into a new version (`references/upstream.md`, section 3; the owner is named in `local/user.md`).
- **Publishing needs consent.** Push and pull request only after the user says yes in this session. Run `scripts/check-private.ps1` before every commit.
