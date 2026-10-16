// Claude Code hooks that turn two rules of this skill into barriers (references/learning.md, section 6).
//   node skill-hooks.cjs guard  - PreToolUse: a working chat may write only learned/ and local/ in this skill's folder
//   node skill-hooks.cjs stop   - Stop: a chat that wrote to learned/ hands the inbox to folding before it closes
// A session whose working folder is this skill (the folding chat) is exempt. Any other folding session creates local/folding.lock first and deletes it at the end; a lock older than 6 h counts as absent.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const norm = p => path.resolve(p).replace(/\\/g, '/').toLowerCase();
const root = path.resolve(__dirname, '..');
const rootN = norm(root) + '/';
const inside = p => p && (norm(p) + '/').startsWith(rootN);
const allowed = p => ['learned/', 'local/'].some(d => (norm(p) + '/').startsWith(rootN + d));

function folding() {
  try { return Date.now() - fs.statSync(path.join(root, 'local', 'folding.lock')).mtimeMs < 6 * 3600e3; }
  catch { return false; }
}

function guard(e) {
  if (folding() || inside(e.cwd)) return; // the folding chat runs in this folder (README.md)
  const i = e.tool_input || {};
  const fp = i.file_path || i.notebook_path;
  if (fp && inside(fp) && !allowed(fp)) {
    deny(`${fp} is in the satisfactory-modding skill. A working chat writes only to learned/ (or local/); folding is a separate step (references/learning.md, sections 1 and 4).`);
  }
  // Bash: block git commands that change the skill's repository; other shell edits are not covered.
  const cmd = i.command || '';
  const gitWrite = /\bgit\b[^|;&\n]*\b(commit|reset|checkout|restore|rebase|merge|push|stash|clean)\b/.test(cmd);
  const touchesSkill = /satisfactory-modding/i.test(cmd);
  if (gitWrite && touchesSkill) {
    deny('git commands that change the satisfactory-modding skill repository run only in a folding session (references/learning.md, section 4).');
  }
}

function deny(msg) {
  process.stderr.write(msg + ' If this is the folding session, create local/folding.lock first.\n');
  process.exit(2);
}

function stop(e) {
  if (e.stop_hook_active || folding() || inside(e.cwd) || !e.transcript_path) return;
  let wrote = false, sent = false, lines;
  try { lines = fs.readFileSync(e.transcript_path, 'utf8').split('\n'); } catch { return; }
  for (const line of lines) {
    if (!line.includes('tool_use')) continue;
    let content;
    try { content = JSON.parse(line).message?.content; } catch { continue; }
    if (!Array.isArray(content)) continue;
    for (const c of content) {
      if (c.type !== 'tool_use') continue;
      const inp = c.input || {};
      const fp = inp.file_path || '';
      if (/^(Write|Edit|MultiEdit)$/.test(c.name) && fp && inside(fp) &&(norm(fp) + '/').startsWith(rootN + 'learned/')) wrote = true;
      if (/learned[\\/][\w.-]+\.md/.test(inp.command || '') && />>|Add-Content|Out-File/.test(inp.command || '')) wrote = true;
      if (JSON.stringify(inp).includes('fold the findings inbox')) sent = true;
    }
  }
  if (!wrote || sent) return;
  let pending = '';
  try { pending = execFileSync('git', ['-C', root, 'status', '--porcelain', '--', 'learned/'], { encoding: 'utf8' }).trim(); }
  catch { return; }
  if (!pending) return;
  let user = '';
  try { user = fs.readFileSync(path.join(root, 'local', 'user.md'), 'utf8'); } catch {}
  const reason = /fold/i.test(user)
    ? 'This chat added entries to the satisfactory-modding inbox (learned/). Send the folding chat named in local/user.md the message "fold the findings inbox" with SendMessage, check it arrived, then close (SKILL.md rule 2).'
    : 'This chat added entries to the satisfactory-modding inbox (learned/). Apply references/learning.md section 3: count the waiting entries and ask the user once if a threshold is met, then close.';
  process.stdout.write(JSON.stringify({ decision: 'block', reason }));
}

let buf = '';
process.stdin.on('data', d => (buf += d));
process.stdin.on('end', () => {
  let e = {};
  try { e = JSON.parse(buf || '{}'); } catch { return; }
  ({ guard, stop })[process.argv[2]]?.(e);
});
