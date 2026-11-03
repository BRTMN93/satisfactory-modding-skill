# Publishing, ficsit.app, licenses, working with someone else's mod

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## ficsit.app (SMR)
- **When the user plans a new mod, search ficsit.app through the API, not with a web search engine.** The web search engine did not find any of the existing railway mods, including a mod with 60 thousand downloads. The API found them at once. Search with several words from the domain (for example: train, station, logistic, dispatch).
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
- **The release package.** Alpakit Release builds all targets and writes one merged zip with `Windows\` (the Steam and the EGS DLLs together), `WindowsServer\` and `LinuxServer\` (`references/build-install-debug.md`, "Release packaging"). Seen in a packaged zip on disk, and in the ficsit.app API, where the SML 3.12.0 release lists the targets `Windows`, `WindowsServer` and `LinuxServer`. ficsit.app keeps one archive per target; SMM's cache names them `<ModRef>_<ver>_<Target>.zip`. Steam and EGS are not separate targets. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
  - **[?]** Whether ficsit.app rejects a zip that lacks a target, or only shows such a mod as incompatible with servers (the version page has a "Server" column).
- **[?] Uploading a version** (docs.ficsit.app, UploadToSMR and the 3.12 guide; API field names checked, the rest not tried):
  - The mod reference cannot change once the mod page exists. A Hidden mod sends no Discord notice, so unhide it before the first version.
  - A C++ mod waits for automated approval (about 1 to 3 minutes); a Blueprint-only mod is instant.
  - After the upload set Compatibility to `Works` for both branches. The API fields are `compatibility { EA EXP }`; SML shows `Works` for both. There is also a controller-compatibility field, default `Untested`.
  - The first changelog lines go to the Discord channel #mod-updates. Read the ficsit.app Content Policy. The help page has a `.uplugin` validator.
  - An update is: bump `SemVersion` and `VersionName` (and `Version`), the SML dependency and `GameVersion`; never lower the version.
  - Uploading new versions is blocked until the questions about network activity (transparency) and generative-AI use are answered.
  - **Tags** are set by moderators on the Edit Mod page; SMM filters by tag (all or any), although one docs page says it cannot.
  - **Prerelease:** SMM never installs a version such as `1.2.0-beta` by itself; a tester picks it under "Change version" (the left half locks the exact version, the right half means that version or newer). That makes a beta channel possible.
  - **Release notes for a mod that places, moves or configures base-game buildings:** state that changes can remain in a save after the mod is uninstalled. The docs know of two broken saves in modding history, repaired with a save editor from ficsit.app/tools. Test on copies of saves (`SKILL.md`, rule 11). (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **A mod page that exists on ficsit.app without any uploaded version is still returned by the public API, so a non-null `getModByReference` does not mean a version is out.** `{ getModByReference(modReference: "<Ref>") { id approved hidden created_at last_version_date versions { version approved } } }` returns `"approved":true,"hidden":true,"last_version_date":"0001-01-01T00:00:00Z","versions":[]` for such a page, and REST `GET https://api.ficsit.app/v1/mod/<mod id>/versions` returns `{"data":[],"success":true}`. So the versions list shows before a first release whether anything was uploaded under a higher number (SMM would then not offer a lower one). Evidence: both responses for an author's hidden page with no upload, queried without login. **[?]** Whether a version uploaded but still waiting for approval shows up in these unauthenticated queries was not checked; the author's panel is the final word. (2026-11-03, ficsit.app API v1/v2)

## Licenses and forks
- Before forking or releasing someone else's mod, check the license: `gh api repos/O/R/license --jq .license.spdx_id`.
- GPL-3.0 allows releasing a fork, but you must keep the license, make the source available and credit the author.
- A fork is released under a **different mod reference**.
- First try to contact the author: an issue or PR, the Satisfactory Modding Discord, ficsit.app.

## Contributing to someone else's mod (GitHub)
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

## Your own mod's repository
- **Before the first push, scan the repository's whole history for absolute paths with a user name and for the AI tool's local folders** (for example a path into the user's profile that a test script used to find a packaging script). Committed scripts take such paths from a parameter or an environment variable. A path found after the push needs a rewrite of the history. Evidence: a mod repository's history was rewritten before its first push to remove such paths from every commit. (2026-10-03, game 502094, SML 3.12.0)
