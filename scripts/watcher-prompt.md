# Watcher prompts

Every run that lasts more than a few minutes gets TWO watchers, started together right after the run starts and stopped together (`TaskStop`) when it ends: the result watcher (`scripts/watch-run.sh`, first prompt) and the behaviour watcher (`scripts/behaviour-read.sh`, second prompt), both on Sonnet at medium effort (Haiku 4.5 did not follow the result watcher's prompt reliably, 2026-10-07). The result watcher alone misses a mod that misbehaves with every check green (`references/test-automation.md`).

## Result watcher

The prompt for the sub-agent that watches one automated test run with `scripts/watch-run.sh` (`references/test-automation.md`). Fill in the `<…>` parts and paste the text between the lines unchanged. Prompts retyped for each run lost the `done` line and the verbatim forwarding, and one that told the watcher to sleep first made it arm a background wait and end its turn before the run started.

Read the start values BEFORE the run starts (they describe the old log), then start the run and the watcher together. An id read after the run's game has started is already the new log's, and a wait for a new log then never ends (a two-hour run got no watchers that way, 2026-10-07). The script reports a `previous log:` result only if it lies after `FROM`, so the run before is never taken for this one. A watcher that runs while the run still packages can see `GAME CLOSED` at once when the game before it was killed (`references/test-automation.md`). Expected noise is not listed in the prompt: it goes into `IGNORE_PATTERN` (an extended regex), which the script applies. `<max calls>` is the run's timeout in seconds / 30, rounded up. Start values: `FROM` is `wc -l < "$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"`, `ID` is `head -n 1 "$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log" | tr -dc "0-9.:-"`. The ID must be in this form (the script's own); a raw first line makes the first call start again from line 0.

---
You watch one automated test run of a Satisfactory mod. Do not analyse, fix or retry anything, and never stop to ask.

0. If the SendMessage tool is not loaded yet, load it first with ToolSearch, query "select:SendMessage".
1. Run this in the foreground with a timeout of 120000 ms, never in the background:
   `MOD_LOG_CATEGORY=<LogMyMod> TEST_TAG=<MYMOD_TEST> STATUS_PATTERN='<regex of repeated status lines, or empty>' IGNORE_PATTERN='<regex of expected noise lines, or empty>' bash "<skill folder>/scripts/watch-run.sh" <test> <FROM> <ID>`
   Never use sleep, a monitor or a background task: the script waits by itself.
2. The last line of the output is `LINES <n> <id>`. Use `<n>` and `<id>` as FROM and ID of the next call.
3. If the output has any line other than `RUN …`, `no new step for …`, `game not started yet` and `LINES …`, send the WHOLE output of that call verbatim, every line including the `RUN` line, with SendMessage to "main".
4. Stop after a call whose output has a `RESULT` line, a `previous log:` line or `GAME CLOSED, watch over`, once you have sent it. Stop also after <max calls> calls; before you stop on the cap, send `CAP REACHED, LINES <n> <id>` with SendMessage to "main".
5. Your final answer is the single word `done`, nothing more.
---

## Behaviour watcher

Model: Sonnet, medium effort. Start value: `FROM` is the log's line count right after the run's game has started (`wc -l < "$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"`). `DROP_PATTERN` is an extended regex of repeated lines the watcher does not need (e.g. per-station status lines), or empty.

---
You watch the BEHAVIOUR of one automated test run of a Satisfactory mod (scenario <test>, started <time> in the game log). Another watcher reports results and errors; you look for misbehaviour a player would notice. Do not analyse code, fix or retry anything, never stop to ask, never edit files.

0. If the SendMessage tool is not loaded yet, load it first with ToolSearch, query "select:SendMessage".
1. Loop: run in the foreground with a timeout of 150000 ms, never in the background, never add your own sleep:
   `MOD_LOG_CATEGORY=<LogMyMod> DROP_PATTERN='<regex or empty>' bash "<skill folder>/scripts/behaviour-read.sh" <FROM>`
   The last line is `LINES <n>`: use n as the next FROM. The script waits 90 s by itself.
2. What the lines look like: <the shapes of the scenario's status lines and steps>.
3. NORMAL in this scenario (do not report): <what the scenario does on purpose: objects switched off, power cut, waits by design>.
4. REPORT at once with SendMessage to "main", starting with `BEHAVIOUR <test>:` and quoting the evidence lines verbatim (at most 8): the same command repeated for one object (more than twice in 5 minutes); an object standing still or in an error state for more than 2 minutes while it has work; a task in one state for more than 10 minutes; two objects claiming one place; a loaded object without a task for long; a value flipping between two states in every status table; any warning or error line other than <expected ones>. Report each distinct anomaly once.
5. Stop when the output has a line with `RESULT` or `GAME CLOSED`, after sending that line to "main", or after <max calls> calls. Your final answer is the single word `done`.
---
