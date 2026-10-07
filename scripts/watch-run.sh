#!/bin/bash
# watch-run.sh <test> <from_line> [<log_id>]     (bash, e.g. Git Bash on Windows)
# For a sub-agent that watches an automated test run in a loop (references/test-automation.md).
# Waits $WATCH_SECONDS (default 30), then reads the game log lines added since <from_line> and prints:
#   RUN <test> started <time of the first line with the test tag>
#   problem lines (mod errors, failed checks, crash, result), deduplicated, without timestamps, at most 10
#   or "no new step for N s" when no line with the test tag came, status lines (STATUS_PATTERN) not counted
#   GAME CLOSED, watch over   when the game process is gone after new log lines
#   game not started yet      when there is no game and no new line (packaging, start)
#   LINES <n> <log_id>   the line number and the log's id to pass to the next call. The id is the time in the
#   log's first line: a new game start renames the old log, so another id means a new log, read from line 0
# Set for your mod:
#   MOD_LOG_CATEGORY  the mod's log category, e.g. LogMyMod (default LogMyMod)
#   TEST_TAG          the prefix your test scenario puts on its log lines, e.g. MYMOD_TEST (default MYMOD_TEST).
#                     Its result lines are expected as "<TEST_TAG> RESULT" or "RESULT PASS|FAIL|CRASH|TIMEOUT",
#                     failed checks as "<TEST_TAG> ... FAILED".
#   STATUS_PATTERN    optional extended regex of the status lines a scenario repeats while it waits (e.g. a train
#                     table every 30 s). They do not count as a new step, so a run that stands still is reported.
LOG="$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"
TEST="$1"; FROM="${2:-0}"; ID="${3:-}"
STEP="${WATCH_SECONDS:-30}"
CAT="${MOD_LOG_CATEGORY:-LogMyMod}"
TAG="${TEST_TAG:-MYMOD_TEST}"
sleep "$STEP"
# The game renames its log when it starts: for a moment there is no log file. Say so and keep the caller's position.
if [ ! -f "$LOG" ]; then echo "RUN $TEST started ?"; echo "game not started yet"; echo "LINES $FROM $ID"; exit 0; fi
N=$(wc -l < "$LOG" 2>/dev/null || echo 0)
NOWID=$(head -n 1 "$LOG" 2>/dev/null | tr -dc "0-9.:-")
{ [ "$N" -lt "$FROM" ] || { [ -n "$ID" ] && [ "$ID" != "$NOWID" ]; }; } && FROM=0
STARTED=$(grep -m1 "$TAG" "$LOG" 2>/dev/null | sed -E 's/^\[([^]]*)\].*/\1/')
echo "RUN $TEST started ${STARTED:-?}"
# A new log: the run that was watched may have ended in the renamed one (a queue starts the next game at once)
if [ -n "$ID" ] && [ "$ID" != "$NOWID" ]; then
  B=$(ls -t "$(dirname "$LOG")"/FactoryGame-backup-*.log 2>/dev/null | head -n 1)
  [ -n "$B" ] && grep -E "$TAG RESULT|RESULT (PASS|FAIL|CRASH|TIMEOUT)" "$B" | sed -E 's/^\[[^]]*\]\[[^]]*\]//' | tail -n 3 | sed 's/^/previous log: /'
fi
NEW=$(tail -n +"$((FROM + 1))" "$LOG" 2>/dev/null | head -n "$((N - FROM))")
PROBLEMS=$(echo "$NEW" | grep -E "$TAG (FAILED|RESULT)|$TAG .*FAILED|$CAT: (Error|Warning)|Fatal error|Unhandled Exception|RESULT (PASS|FAIL|CRASH|TIMEOUT)" \
  | sed -E 's/^\[[^]]*\]\[[^]]*\]//' | awk '!seen[$0]++' | head -10)
if [ -n "$PROBLEMS" ]; then echo "$PROBLEMS"; fi
PROGRESS=$(echo "$NEW" | grep "$TAG" | { if [ -n "$STATUS_PATTERN" ]; then grep -Ev "$STATUS_PATTERN"; else cat; fi; })
if [ -z "$PROGRESS" ]; then echo "no new step for $STEP s"; fi
if ! tasklist 2>/dev/null | grep -Eqi "FactoryGame(Steam|EGS)-Win64"; then
  # No game and nothing new in the log: the run is still packaging or starting
  if [ "$N" -gt "$FROM" ]; then echo "GAME CLOSED, watch over"; else echo "game not started yet"; fi
fi
echo "LINES $N $NOWID"
