# Tools and scripts

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## Tools and scripts

**Following the game log (PowerShell).** Waits for the game, prints new matches and exits together with the game. Handles log rotation.
```powershell
$log = "$env:LOCALAPPDATA\FactoryGame\Saved\Logs\FactoryGame.log"
$pattern = 'LogMyMod|LogSatisfactoryModLoader|Fatal error|World Serialization'
while (-not (Get-Process FactoryGameSteam-Win64-Shipping -EA SilentlyContinue)) { Start-Sleep 2 }
$seen = 0
while ($true) {
    $running = Get-Process FactoryGameSteam-Win64-Shipping -EA SilentlyContinue
    $lines = @(Select-String -Path $log -Pattern $pattern -CaseSensitive -EA SilentlyContinue)
    if ($lines.Count -lt $seen) { $seen = 0 }            # the game rotated the log
    $lines | Select-Object -Skip $seen | % { $_.Line }
    $seen = $lines.Count
    if (-not $running) { break }
    Start-Sleep 2
}
```

**Waiting for packaging to finish:**
```bash
until grep -qE "Result: (Succeeded|Failed)" package.log; do sleep 3; done
```

**Reading Oodle-compressed data outside the game** (e.g. your own cache). The `FOodleCompressedArray` format: int32 size after decompression, int32 compressed size, Oodle stream. The library `oo2core_9_win64.dll` is in `<UE-CSS>\Engine\Binaries\DotNET\AutomationTool\AutomationScripts\BuildGraph\`.
```python
import ctypes, struct
from ctypes import c_void_p, c_ssize_t, c_int, create_string_buffer
f = ctypes.WinDLL(r"<path>\oo2core_9_win64.dll").OodleLZ_Decompress
f.restype = c_ssize_t
f.argtypes = [c_void_p, c_ssize_t, c_void_p, c_ssize_t, c_int, c_int, c_int,
              c_void_p, c_ssize_t, c_void_p, c_void_p, c_void_p, c_ssize_t, c_int]   # 14 arguments
raw, comp = struct.unpack_from("<ii", data, 0)
out = create_string_buffer(raw)
n = f(data[8:8+comp], comp, out, raw, 1, 0, 0, None, 0, None, None, None, 0, 3)     # n == raw
```
Without numpy and Pillow, you can compare images and write PNG in pure Python (`zlib` + `struct`). Comparing two 8K images takes about 24 s.

**Searching for names in Blueprint assets:** extract from the `.uasset` bytes the strings matching `[\x20-\x7e]{5,}`, because `strings.exe` is not available by default.

**`<Game>\CommunityResources\`**: the files, `Headers.zip` and the placeholder assets are described in `references/setup.md` (step 5). `Docs\en-US.json` has 114 native classes with their `ClassName` lists. The `FactoryGame.usmap` and `CustomVersions.json` are what FModel needs (next bullet).
- **[?]** Browsing the real game assets: FModel with UE version `GAME_UE5_6`, the Custom Versions text set to `CustomVersions.json` and Local Mapping File set to `FactoryGame.usmap` opens `FactoryGame-Windows.utoc` and gives asset and class paths and widget trees; faster than strings over the stub `.uasset`. The files exist; FModel was not run.
- **[?]** The Asset Toolkit (docs.ficsit.app, `CommunityResources_AssetToolkit`) is a dumper mod plus a generator that builds a starter project with the real widgets and icons. The dump is started with `FactoryGameSteam.exe -DumpAllGameAssets -RootAssetPath=/Game -ExcludePackagePaths=/Game/WwiseAudio -PackagesPerTick=32 -ExitOnFinish -log -NewConsole -RenderOffscreen -norhithread` (about 8.5 GB, no server targets); the generator runs `UnrealEditor-Cmd.exe <uproject> -run=AssetGenerator -DumpDirectory=... -stdout -unattended` (about 7 GB; move `Content` away first; out-of-memory crashes can be resumed). Never push the generated `Content` to GitHub. It is worth the disk only for heavy UI work. Not tried. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Hiding a plugin from the engine [source].** A plugin file named `<Mod>.uplugin.disabled` is not seen by UE or UBT, which look for the extension `.uplugin` (UBT `CppIncludeLookup.cs:260`). Docs say one broken mod folder can block packaging of every mod in the project, so rename the file and regenerate the project files instead of deleting the mod. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)

**Reading the game's shipping DLL with `dumpbin`.** `dumpbin /exports <Game>\FactoryGame\Binaries\Win64\FactoryGameSteam-FactoryGame-Win64-Shipping.dll` lists the `FACTORYGAME_API` class members with their RVA, and `dumpbin /disasm` with the `.pdb` beside the DLL shows function names at call sites, which is enough to follow a native function the headers only declare. Run it from PowerShell (or cmd) with the MSVC tools on the path: Git Bash rewrites `/exports` and `/disasm` into paths. (2026-11-01, game 513885, MSVC 14.38)

**Git/GitHub**
- Check whether a commit applies cleanly to another branch (cherry-pick simulation without touching files):
  `git merge-tree --write-tree --merge-base=<commit>^ <branch> <commit>`
- Change a commit message without changing the content: `git commit-tree <sha>^{tree} -p <parent> -F -` (keep `GIT_AUTHOR_DATE`), then `git update-ref`, and finally `git diff old new` must be empty.
- Partial clone: `git clone --filter=blob:none --no-checkout --sparse -b <branch> <url>` and `git sparse-checkout set <path>`.
- Inspecting other people's forks:
  - `gh api repos/O/R/compare/A...B`,
  - `gh api "repos/O/R/commits?sha=<branch>"`,
  - `gh api repos/O/R/issues/<N>/timeline`: a "referenced" event means someone pushed a commit mentioning your PR.
- Drawing a layout from a log dump in PowerShell: `$Matches` is overwritten by every `-match`, also the one inside an `if` further down the loop, so copy it (`$m = $Matches`) right after the match you need, or a nested test like `$text -match 'platform'` silently loses the fields of the outer match (14 of 50 tracks vanished from a drawing that way). Numbers written into SVG with `"$x"` follow the current culture: a system with a decimal comma writes `12,5` and the SVG is invalid; set `[CultureInfo]::CurrentCulture = [CultureInfo]::InvariantCulture` at the top of the script or format with `.ToString([CultureInfo]::InvariantCulture)`. A quick preview of the SVG without a browser tool: `msedge --headless=new --disable-gpu --hide-scrollbars --window-size=W,H --screenshot=out.png file:///path.svg`. (2026-10-06, Windows 11, PowerShell 5.1, Edge)
- **[source]** The FicsIt-Networks reflection pages list game classes with their functions and properties, a quick reference before opening the headers (for example `RailroadSignal`, `domains/railroad/signals.md`).
- **[?]** Open-source mods worth reading per topic (the docs page `Development_OpenSourceExamples` predates Actor Mixins and the Blueprint hook system, and some entries use the old SCS hooks; sources not opened here): Ficsit Remote Monitoring (an HTTP/WebSocket server inside a mod, client and server module split, access transformers, `FGGameUserSettings`); MAM Enhancer (widget injection, widget Blueprint hooks, live config preview); Free Samples (server-only subsystem, per-player data, soft-class fields in saves); Screw It (asset-registry subclass discovery, async loading, bulk CDO edits, hybrid root module); Early Free Blueprint Designer (content tag scan). Rail-related examples are in `domains/railroad/`. (2026-10-24, game 513885, SML 3.12.0, docs.ficsit.app)
- **Long scripts go into a file, not into a command line.** A long inline script failed in the shell (`ENAMETOOLONG: name too long, uv_spawn`; a Bash heredoc with a long Python script: `unexpected EOF while looking for matching`), the same in several sessions. Backslashes in a heredoc that feeds a Python string were also mangled (`\f` became a form feed). Write the script with the file tool and run the file. (2026-10-07, game 502094, SML 3.12.0)
- **A commit message written to a file by Windows PowerShell 5.1 can start with a byte-order mark** (`-Encoding utf8` writes one), which ends up at the start of the commit subject. Commit with `git commit -m`, or write the file without a BOM, and check `git log -1 --format=%B | head -c3 | od -An -tx1` is not `ef bb bf`. Evidence: two commits had to be redone after a sub-agent wrote the message files. (2026-10-03, game 502094, SML 3.12.0)
- **Windows PowerShell 5.1 does not expand a variable inside a native-command argument that starts with `-`.** `& RunUAT.bat -ScriptsForProject=$p PackagePlugin "-project=$p"` passed the literal `$p` to the first argument: UAT stopped with `Project '$p' does not exist relative to any entries in *.uprojectdirs`. With the whole argument in quotes (`"-ScriptsForProject=$p"`) the variable is expanded; a path written out needs no expansion. (2026-11-03, Windows PowerShell 5.1)
- **[?]** Researching game rules with a web-fetching tool returns a small model's summary, not the page; mark quotes as verbatim or summary, list where sources contradict each other, and note pages that refused the fetch (some wikis and forums did). (2026-10-04, game 502094, SML 3.12.0)
- Shell and encoding traps met when cleaning up a project's documents (`printf` turning `` in a Windows path into BEL, mass edits of UTF-8 text): `references/project-hygiene.md`, section 7.
