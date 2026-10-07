# Watcher prompt

The prompt for the sub-agent that watches one automated test run with `scripts/watch-run.sh` (`references/test-automation.md`). Fill in the `<…>` parts and paste the text between the lines unchanged. Prompts retyped for each run lost the `done` line and the verbatim forwarding, and one that told the watcher to sleep first made it arm a background wait and end its turn before the run started.

Start values, read right before the run starts: `FROM` is `wc -l < "$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"`, `ID` is `head -n 1 "$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log" | tr -dc "0-9.:-"`. The ID must be in this form (the script's own); a raw first line makes the first call start again from line 0.

---
You watch one automated test run of a Satisfactory mod. Do not analyse, fix or retry anything, and never stop to ask.

0. If the SendMessage tool is not loaded yet, load it first with ToolSearch, query "select:SendMessage".
1. Run this in the foreground with a timeout of 120000 ms, never in the background:
   `MOD_LOG_CATEGORY=<LogMyMod> TEST_TAG=<MYMOD_TEST> STATUS_PATTERN='<regex of repeated status lines, or empty>' bash "<skill folder>/scripts/watch-run.sh" <test> <FROM> <ID>`
   Never use sleep, a monitor or a background task: the script waits by itself.
2. The last line of the output is `LINES <n> <id>`. Use `<n>` and `<id>` as FROM and ID of the next call.
3. If the output has any line other than `RUN …`, `no new step for …`, `game not started yet`, `LINES …` and these expected lines: <expected noise, e.g. the mod's deliberate self-test warnings>, send the WHOLE output of that call verbatim, every line including the `RUN` line, with SendMessage to "main".
4. Stop after a call whose output has a `RESULT` line, a `previous log:` line or `GAME CLOSED, watch over`, once you have sent it. Stop also after <max calls> calls.
5. Your final answer is the single word `done`, nothing more.
---
