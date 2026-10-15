#!/bin/bash
# behaviour-read.sh <from_line> [<log_id>]     (bash, e.g. Git Bash on Windows)
# The reader of the behaviour watcher (watcher-prompt.md, second prompt). Waits $WATCH_SECONDS (default 90), then prints the
# lines of $MOD_LOG_CATEGORY added to the game log since <from_line>, the timestamp cut to the time, without lines matching
# $DROP_PATTERN (repeated status lines the watcher does not need); "GAME CLOSED" when the game process is gone; last line
# LINES <n> <log_id>, to pass to the next call. The id is the time in the log's first line (as in watch-run.sh): when it
# differs from the one passed, a new game has renamed the old log, so the rest of the newest backup log is printed first and the
# new log is read from line 0. Without an id the script only resets to line 0 when the log shrank.
LOG="$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"
FROM="${1:-0}"; ID="${2:-}"
CAT="${MOD_LOG_CATEGORY:-LogMyMod}"
sleep "${WATCH_SECONDS:-90}"
if [ ! -f "$LOG" ]; then echo "no log yet"; echo "LINES $FROM $ID"; exit 0; fi
N=$(wc -l < "$LOG")
NOWID=$(head -n 1 "$LOG" 2>/dev/null | tr -dc "0-9.:-")
show() { grep "$CAT" | { if [ -n "$DROP_PATTERN" ]; then grep -Ev "$DROP_PATTERN"; else cat; fi; } | sed -E "s/^\[[0-9.]+-([0-9.]+):[0-9]+\]\[ *[0-9]+\]$CAT: /\1 /"; }
if [ -n "$ID" ] && [ "$ID" != "$NOWID" ]; then
  B=$(ls -t "$(dirname "$LOG")"/FactoryGame-backup-*.log 2>/dev/null | head -n 1)
  [ -n "$B" ] && tail -n +"$((FROM + 1))" "$B" | show
  FROM=0
fi
[ "$N" -lt "$FROM" ] && FROM=0
tail -n +"$((FROM + 1))" "$LOG" | head -n "$((N - FROM))" | show
if ! tasklist 2>/dev/null | grep -Eqi "FactoryGame(Steam|EGS)-Win64"; then echo "GAME CLOSED"; fi
echo "LINES $N $NOWID"
