# Project hygiene: keeping the state document small and the methodology enforced

Part of the `satisfactory-modding` skill. For a mod worked on over many sessions or chats, each of which starts by reading a state document. Written after a long project where the methodology lived only as rules in a plan, not as a step that closes a session: the state document grew to about 400 KB (about 77% of it closed sessions' material, and every later session paid to read it), backlog items had a pass criterion only per session and the criterion was sometimes changed after a failing run, the list of popular layouts came from one source with no evidence table, and the same test world was rebuilt separately for each session. Markers: no marker = seen in practice, **[source]** = read from code or docs, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 1. The state document has a size budget

- The document every session reads in full at its start has a budget (about 100 KB). Closing a session includes a size check, and a session whose document is over budget archives before it closes.
- Archiving: move the entries of closed sessions to an archive file. The active file keeps one table row per session (a line with a link to the archive), the open backlog items each with the session that will check it, and the current state.
- Archiving moves text verbatim by byte or line ranges; a model does not summarise it. Check: the sorted lines of the original equal the sorted lines of active file plus archive, minus the lines added as pointers, and both files are valid UTF-8.
- `scripts/check-project-state.ps1 -StateFile <file>` reports the size against the budget and the open items that lack a pass criterion (section 2). `-OpenPattern <regex>` says what an open item looks like, and `-CriterionPattern <regex>` (default `Passes when:`) the criterion line, so a project that keeps its state document in another language gives its own word.

## 2. Every open backlog item says when it passes

Each open item has a line `Passes when:` with three parts: scenario and save, a log pattern or a number to meet, and the symptom that would show without the fix. The session that checks the item freezes this criterion before the run. Changing it after a run is allowed only with the reason written in that session's findings. A gate review compares the result with the criterion, not just with PASS; a FAIL is not accepted as "measurement evidence". Where possible the session that closes an item does not write its criterion (a sub-agent proposes it at the start, the session approves it).

## 3. Coverage of layouts needs evidence that stays current

- The list of popular layouts (tracks, flows, topologies) has at least two sources outside the project, and a table `layout → evidence (log file) → code it ran on → open items`.
- After every code change that touches a mechanism, the evidence for that mechanism is "needs a repeat" until it is re-run. The table is an input of the release gate (`references/testing.md`).
- "A popular layout is never out of scope" stays; being popular among players is the entry criterion and the user decides the list.

## 4. One map of saves, worlds and scenarios

Keep one source of truth: `save or test world → layouts → scenarios → sessions`. A session that plans a rebuild of a test world collects the needs of all later sessions that will use it, so one build list replaces several. Protection against scenarios coupling to each other: the base save is read-only, each scenario gets its own run, and the signalling state is dumped before a series.

## 5. Methodology changes get an independent arbiter

Before a change to the working method is adopted, a separate agent on a strong model gets a neutral brief ("check on the facts whether the project already has this and where the gaps are") without the author's verdict. In the case that produced this file the arbiter reversed part of the conclusions: what the author called "already existing" had real gaps, and an idea called good had a timing flaw. Calling one's own idea "already done" without reading the documents is an error.

## 6. Enforcing it

A rule that exists only in the plan is not enough. Three elements belong into a project from its start, not after dozens of sessions:
- **A line in the starting prompt of every session:** "Is the state document over its budget? Does every open item have `Passes when:`?"
- **The check script** above, run at the start and at the close of a session.
- **A step in the closing checklist and in the gate:** archive when over budget, criteria frozen and compared, evidence table refreshed, entries for `learned/` written and the folding chat told (`SKILL.md`, rule 2).

## 7. Pitfalls met in this work

- Bash `printf` turns `\a` in a Windows path (`kopie\archiwum` style, any path with a segment starting with `a`) into a BEL character. Text that holds paths goes into a file or a heredoc, not through `printf`.
- Mass edits of UTF-8 documents with non-ASCII text work on raw bytes (`sed`/`awk` with `LC_ALL=C`) or with an editor tool that keeps bytes; a Perl `:utf8` layer double-encodes the whole file.

## 8. Context size: compact between tasks

A long context is read again on every call, so its size costs more than the choice of model (cache reads were 60-69% of the cost of the Opus 5.5 chats measured on 2026-10-06, and those chats ran at 355-440k tokens of context on average).

- **When:** between tasks (after a series of runs, after a review, before the next big step) the session checks its context size (in the Claude Code desktop app with `mcp__ccd_session_mgmt__get_usage`). From about **500k tokens**, or earlier when the next task adds a lot, it compacts instead of starting a part b of its work.
- **Hard limits.** The check is not only "between tasks": a session also checks after every finished run of a series and after every review. At **500k** it starts no new task and no new series, and finishes the current one at its nearest checkpoint (a series ends after the run in progress, not after all the runs queued). At **600k** it stops whatever it is doing, writes the checkpoint and compacts or hands the rest over (steps below); a task that is not finished is no reason to go on, because a long task is exactly what pushes a context to 700k.
- **Steps:**
  1. Write a checkpoint file: the state of the criteria with evidence, the table of runs, open bugs and review notes, the next step, the files in progress. Make a local commit of the code, no push.
  2. Tell the user and give two ready messages to type one after the other: `/compact Keep: <the session's card>, the checkpoint file <path>, open bugs and findings. Drop: logs and tool results.` and `Continue from the checkpoint.` A session cannot run `/compact` itself, and after a compact it does not go on without a message.
  3. After the compact it reads the checkpoint and its card, then works on.
- **At most two compacts per session.** When the scope still does not fit, the session closes at a stable point and hands over a part b.
