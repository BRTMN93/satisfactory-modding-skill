# satisfactory-modding

A [Claude Code](https://claude.com/claude-code) skill for modding Satisfactory 1.x: Unreal Engine 5.6.1-CSS, Satisfactory Mod Loader (SML) 3.12, C++ and Blueprints.

It covers setting up the environment, mod structure, SML modules and hooks, config, multiplayer, packaging with Alpakit or RunUAT, installing and debugging in the game, performance, rendering, railways (trains, timetables, stations, signals and blocks, routes given to the autopilot), testing and publishing on ficsit.app. Every statement carries a marker: verified in the packaged game, read from source only (**[source]**), or uncertain (**[?]**).

## Install

Clone into your skills folder. The folder name must stay `satisfactory-modding`:

```bash
git clone https://github.com/BRTMN93/satisfactory-modding-skill.git ~/.claude/skills/satisfactory-modding
```

Claude Code picks the skill up on its own when you work on a Satisfactory mod, or you can call it with `/satisfactory-modding`.

## The skill learns from your sessions

Modding knowledge goes stale with every game, SML and engine update, so the skill is built to collect what each session discovers:

1. **While you work,** Claude writes new facts, corrections of wrong statements and confirmations of untested ones into `learned/findings.md`, with the evidence and the versions they were found on. It tells you in one line each time.
2. **When a modding task is done** and enough has piled up, Claude asks once whether to fold the findings into the reference files, and whether to send them here as a pull request.
3. **Nothing is published without your yes.** Before a commit, `scripts/check-private.ps1` checks the files for your private strings.

The full procedure is in [`references/learning.md`](references/learning.md). The loop only runs in sessions where the skill is active.

### Recommended setup: a dedicated chat for the skill

If you mod across several chats at once (Claude Code desktop app, same computer), keep one separate chat just for the skill:

- **The working chats record, the skill chat folds.** Each modding chat has the evidence fresh, so it writes its own entries to `learned/findings.md`. When it is done it sends the skill chat a short message ("fold the findings inbox") instead of editing the reference files itself.
- **The skill chat does only the folding:** it moves the entries into the reference files, runs `scripts/check-private.ps1`, reviews the diff and commits locally. That is mechanical work, so a mid-size model at medium effort (for example Sonnet, medium) is enough and costs little. Your working chats keep their context and their stronger model for the actual modding.
- **One chat edits the skill,** so two chats never fold into the same files or commit over each other.
- Give the skill chat a fixed name (for example `Skill - satisfactory-modding`) and keep it open, because the other chats find it by that name. Putting the chats in the same sidebar group is only for your own overview.
- Pushing and pull requests stay your call: the skill chat does it only when you tell it to in that chat.

## Your private settings

Create a `local/` folder in the skill (it is ignored by git):

- `local/user.md`: your conventions, for example the git identity and attribution rules for commits. The skill reads it and follows it.
- `local/private-strings.txt`: one string per line that must never be published (user name, e-mail, Steam ID, private paths, names of unpublished mods). `scripts/check-private.ps1` (PowerShell) blocks a commit that contains any of them.

## Contributing

The easiest way is to let the skill do it: say yes when it offers a pull request. It forks the repository, commits the folded findings on a `findings/<date>-<topic>` branch and opens the pull request with the evidence.

By hand: fork, edit the files in `references/` (or add entries to `learned/findings.md`), keep the markers honest, and say in the pull request what you tested, how and on which game changelist, SML and engine version.
