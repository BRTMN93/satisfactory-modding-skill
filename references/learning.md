# Learning loop: recording findings and sending them upstream

Part of the `satisfactory-modding` skill. This file explains how the skill grows: what to record during work, where, when to ask the user to fold findings into the skill, and how to send them to the skill's upstream repository as a pull request.

## Why

Most of this skill was learned the hard way: a crash, a wasted 47-minute build, a hook that ate VRAM. The game, SML and the engine change, and the reference files go stale. Every modding session discovers something: a fact the skill does not have, a statement that turned out wrong, or a **[source]** claim that now has a test behind it. If nobody writes it down while the evidence is fresh, the next session pays for it again. Users who share the skill send their findings back, so everyone's copy gets better.

## 1. Record while you work

Write to `learned/findings.md` (in this skill's folder) as soon as something is established, not at the end of the session. Context gets compressed and evidence gets lost.

**Record:**
- a fact about the game, SML, the CSS engine, Alpakit, SMM, ficsit.app or the toolchain that the skill does not have,
- a **correction**: the skill says something that the current session proved wrong or outdated (wrong path, renamed class, changed behaviour, a step that no longer works),
- a **confirmation**: a **[source]** or **[?]** statement that has now been tested in the packaged game. The marker can then be removed,
- a measured number (build time, cost of a call, memory) with the hardware or conditions it was measured on.

**Do not record:**
- design decisions of the user's own mod, project plans, names of unpublished mods,
- personal data: names, e-mail addresses, Steam IDs, save names, absolute paths with user names (use `<Game>`, `<Project>`, `<UE-CSS>`, `%LOCALAPPDATA%`),
- anything already in the skill. Search first (`grep -ri <keyword>` over the skill folder). If the skill has it but less precisely, record a correction instead of a duplicate,
- guesses without a marker.

Mention each new entry to the user in one short line ("Recorded in the skill's findings: …"), so they know it happened and can object.

## 2. Entry format

Entries are grouped by the reference file they belong to (`## references/<file>.md`). A finding that needs a new file goes under `## New file: <name>.md`. Corrections go under `## Corrections`, each naming the file and the wrong statement.

```markdown
- **[source]** One self-contained paragraph that can be pasted into the target file almost as is: what, why it matters, how to use or check it. Code, log lines and file:line references verbatim. Evidence: <log line, test, file:line or URL>. (2026-10-02, game 502094, SML 3.12.0)
```

- Marker first, the same as in the reference files: no marker = verified in the packaged game, **[source]** = read from code or docs, **[?]** = uncertain.
- The trailing parentheses carry the date and the versions the finding was made on. Without versions a finding cannot be trusted after the next game update.
- When a later test changes an entry's status, edit the entry in place. Do not add a second entry about the same thing.
- **Facts reported by the user** count as verified when they come with evidence from the packaged game (a log line, a file name, a reproducible step). A cause you inferred from them but did not check gets its own sentence marked **[?]**.
- **Unknown versions:** write `versions unknown` instead of guessing, or ask the user if it is a quick question. Do not copy the skill's baseline versions into an entry.
- **Correction or new entry?** A correction is for a statement that is wrong in general (a wrong path, a renamed class, a step that no longer works). A number that depends on hardware or setup (build times, memory) and differs from the skill is a new measurement entry with the conditions it was taken in. A statement that is right but incomplete gets a new entry, too.

## 3. When to ask the user

At the end of a completed modding task (the goal is reached or the user is wrapping up), look at `learned/findings.md`. Ask **once** if any of these holds:

- 5 or more entries are waiting,
- at least one correction of a statement without a marker is waiting (the skill is currently giving wrong advice),
- an entry prevents a crash, data loss or a multi-hour mistake.

Ask with one question offering:
1. **Fold into the skill**: move the entries into the reference files on this computer.
2. **Fold and send a pull request**: the same, plus a pull request to the upstream repository (section 5).
3. **Not now**: entries stay in the inbox and the question comes back at the next threshold.

Give a short summary with the question: how many entries, to which files, and the most important one. Do not ask in the middle of a task.

After the answer, write one line at the top of `learned/findings.md`, under the title: `Last asked: <date>, <number of entries>, answer: <fold / pull request / not now>`. After "not now", ask again only when at least 5 new entries have come in since that line, or a new correction or crash-prevention entry has appeared. Never ask twice in the same session.

## 4. Folding findings into the skill

1. Put each entry into the right section of its target file, in that file's style. Merge it with neighbouring text when that reads better. Keep the marker and the evidence. The date and versions may go, unless they matter (version-specific behaviour).
2. Corrections replace the wrong text. Confirmations remove the marker in place.
3. If an entry belongs to `SKILL.md` (a rule that prevents a common, costly mistake), keep `SKILL.md` short: one bullet, details in a reference file.
4. Update the table in `SKILL.md` if a new reference file appeared, and `references/open-questions.md` if a question got answered.
5. Remove the folded entries from `learned/findings.md`.
6. Run `scripts/check-private.ps1` (section 7). It must report nothing.
7. If the skill folder is a git repository, commit with a plain message that lists what changed ("Add railway timetable findings, correct Wwise branch advice").

## 5. Pull request to the upstream repository

Only after the user said yes to option 2 in this session. Pushing and opening a pull request publish the content, so they need the user's explicit consent every time.

1. Find the upstream: `git remote get-url upstream`, otherwise `git remote get-url origin`, in the skill folder. If the folder is not a git repository, the upstream is <https://github.com/BRTMN93/satisfactory-modding-skill>. Then tell the user that a pull request needs a git checkout of the skill, and offer to set one up: clone the upstream, copy the local changes over, check the diff together.
2. Fold the findings first (section 4) and run `scripts/check-private.ps1`.
3. Create a branch: `findings/<yyyy-mm-dd>-<topic>`.
4. Commit with the user's own git identity. Follow `local/user.md` for authorship and attribution rules if it exists.
5. If the user cannot push to the upstream, fork it: `gh repo fork --remote --remote-name fork`, then push the branch to `fork`. Otherwise push to `origin`.
6. Open the pull request against the upstream's default branch with `gh pr create --repo <owner/name>`. Title: what changed, in a few words. Body, in English:
   - what was added, corrected or confirmed, grouped by file,
   - evidence for each item (log lines, test description, file:line),
   - game changelist, SML version and engine version it was tested on.
7. Give the user the link. Do not merge, comment or push again without asking.

## 6. Updating from upstream and keeping what only you know

The skill is meant to be a self-feeding encyclopedia: every user records findings, folds them, sends them upstream as a pull request, the maintainer merges, and everybody else updates. Knowledge must not vanish at any step, so an update never overwrites a local statement that the upstream does not have.

Offer an update check once per session, in one line, at the start of a modding task, when the skill folder is a git checkout and `local/last-update-check` is missing or older than 7 days. Also do it whenever the user asks. Everything below needs the user's yes first; `git fetch` only reads, but the merge changes files.

1. **Not a git checkout:** nothing can be merged. Tell the user, and offer to set one up: clone the upstream, copy the local changes over, check the diff together.
2. **Fetch and look:** `git fetch upstream` (otherwise `origin`), then `git log HEAD..<upstream>/main --stat`. Show what is new and wait for the yes. Nothing new: write the date to `local/last-update-check` and stop.
3. **Secure the local state first.** Commit everything tracked, including an inbox with unfolded entries, as it is. `local/` is ignored and stays untouched. After this commit nothing can be lost.
4. **Merge, never replace:** `git merge <upstream>/main`. No rebase, no `reset`, no `--force`, no checkout of single files, no dropping of stashes. On a conflict stop, name the files and resolve together with the user:
   - in `learned/findings.md` keep both sides,
   - in the reference files keep both statements, unless they are the same fact,
   - a local statement that has evidence is never dropped without the user's yes.
5. **Fold the rest of the inbox into the merged text** (section 4). An entry that the upstream already has is a duplicate: drop it and say so. An entry that contradicts the upstream stays in the inbox as a correction, and the user is told, because two claims disagree and one of them needs a new test.
6. Run `scripts/check-private.ps1` (section 7) and write the date to `local/last-update-check`.
7. **Show what only this copy knows:** `git diff <upstream>/main -- SKILL.md README.md references scripts`, summed up in a few lines. That is the knowledge that is not in the official skill yet. Offer a pull request (section 5). The local text stays until the maintainer has merged it; after that the next update shows no difference.

## 7. Privacy check

The skill is public. Before any commit:

- `scripts/check-private.ps1` searches the skill's tracked files for every line of `local/private-strings.txt` (user names, e-mail, Steam ID, private paths, unpublished project names) and exits with an error if it finds one.
- `local/` is in `.gitignore`. It holds the owner's personal conventions (`local/user.md`) and private strings. Never move anything from `local/` into tracked files.
- When a finding came from a private project, describe the fact, not the project.
