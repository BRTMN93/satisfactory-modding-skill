#!/bin/bash
# behaviour-read.sh <from_line>     (bash, e.g. Git Bash on Windows)
# The reader of the behaviour watcher (watcher-prompt.md, second prompt). Waits $WATCH_SECONDS
# (default 90), then prints the lines of $MOD_LOG_CATEGORY added to the game log since <from_line>, the timestamp cut
# to the time, without lines matching $DROP_PATTERN (repeated status lines the watcher does not need); "GAME CLOSED"
# when the game process is gone; last line LINES <n>, to pass to the next call. Resets to line 0 when the log shrank.
LOG="$LOCALAPPDATA/FactoryGame/Saved/Logs/FactoryGame.log"
FROM="${1:-0}"
CAT="${MOD_LOG_CATEGORY:-LogMyMod}"
sleep "${WATCH_SECONDS:-90}"
if [ ! -f "$LOG" ]; then echo "no log yet"; echo "LINES $FROM"; exit 0; fi
N=$(wc -l < "$LOG")
[ "$N" -lt "$FROM" ] && FROM=0
tail -n +"$((FROM + 1))" "$LOG" | head -n "$((N - FROM))" | grep "$CAT" \
  | { if [ -n "$DROP_PATTERN" ]; then grep -Ev "$DROP_PATTERN"; else cat; fi; } \
  | sed -E "s/^\[[0-9.]+-([0-9.]+):[0-9]+\]\[ *[0-9]+\]$CAT: /\1 /"
if ! tasklist 2>/dev/null | grep -Eqi "FactoryGame(Steam|EGS)-Win64"; then echo "GAME CLOSED"; fi
echo "LINES $N"
