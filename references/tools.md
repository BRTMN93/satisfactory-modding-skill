# Tools and scripts

Part of the `satisfactory-modding` skill. Markers: no marker = verified in practice, **[source]** = read from SML or game code, not tested, **[?]** = uncertain. Replace the parts in `<...>` with your own.

## 17. Tools and scripts

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

**Git/GitHub**
- Check whether a commit applies cleanly to another branch (cherry-pick simulation without touching files):
  `git merge-tree --write-tree --merge-base=<commit>^ <branch> <commit>`
- Change a commit message without changing the content: `git commit-tree <sha>^{tree} -p <parent> -F -` (keep `GIT_AUTHOR_DATE`), then `git update-ref`, and finally `git diff old new` must be empty.
- Partial clone: `git clone --filter=blob:none --no-checkout --sparse -b <branch> <url>` and `git sparse-checkout set <path>`.
- Inspecting other people's forks:
  - `gh api repos/O/R/compare/A...B`,
  - `gh api "repos/O/R/commits?sha=<branch>"`,
  - `gh api repos/O/R/issues/<N>/timeline`: a "referenced" event means someone pushed a commit mentioning your PR.
- Drawing a layout from a log dump in PowerShell: `$Matches` is overwritten by every `-match`, also the one inside an `if` further down the loop, so copy it (`$m = $Matches`) right after the match you need, or a nested test like `$text -match 'platform'` silently loses the fields of the outer match (14 of 50 tracks vanished from a drawing that way). Numbers written into SVG with `"$x"` follow the current culture: a Polish system writes `12,5` and the SVG is invalid; set `[CultureInfo]::CurrentCulture = [CultureInfo]::InvariantCulture` at the top of the script or format with `.ToString([CultureInfo]::InvariantCulture)`. A quick preview of the SVG without a browser tool: `msedge --headless=new --disable-gpu --hide-scrollbars --window-size=W,H --screenshot=out.png file:///path.svg`. (2026-10-06, Windows 11, PowerShell 5.1, Edge)
