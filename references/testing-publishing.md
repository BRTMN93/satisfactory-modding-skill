# Testing, release, ficsit.app, working with someone else's mod

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 16. Testing and the pre-release checklist

**Rules**
- Test in the packaged game (rule 1 in `SKILL.md`).
- **Back up the saves before testing.** A copied save keeps its session name, so autosaves during testing overwrite the rotating slots of the *original* session. Rename the test session or turn autosave off.
- Launch parameters that change the resolution can stay in the game's screen settings. Restore the settings after testing.
- When measuring performance, record the conditions. Fullscreen and a borderless window give different results, and with frame generation the engine's frame times are not the same as the displayed frames.
- Manual tests: numbered steps, with a log-watching script confirming each step. Before saving the game, wait until the background work finishes.
- Automation: a separate test mod enabled by a launch parameter (e.g. `-MyModTestBridge`) reads commands from a file (`commands.jsonl`), loads saves, builds and dismantles buildings, samples frame times and memory, and writes the results to files. I picked this pattern up from another modder.
- Check rendering changes by comparing images pixel by pixel (old and new build, same save).

**Launching the game for tests**
- **[source]** Starting the game straight into a save, according to docs.ficsit.app (Development → Testing):
  `-ini:Engine:[/Script/EngineSettings.GameMapsSettings]:GameDefaultMap=/Game/FactoryGame/Map/GameLevel01/Persistent_Level.Persistent_Level,[/Script/EngineSettings.GameMapsSettings]:LocalMapOptions=?skipOnboarding?listen?loadgame=<save name without path and extension>`.
- The documentation also gives a ready-made PowerShell script for launching the game (with, among others, the parameters `-loadLatestSave` and `-multiplayer`) and the parameters `-EpicPortal`, `-NoSteamClient`, `-log`, `-NewConsole`, `-nosplash`, `-windowed`, `-WaitForDebugger`. The syntax comes from a summary of the page, so it must be confirmed against the source. **[?]** Not tested yet.
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
