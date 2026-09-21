// PreToolUse hook for Bash: deterministic enforcement of rules that otherwise
// live only in CLAUDE.md / memory and can be rationalised away by the model.
//
// deny  -> the command is never run (model is told why so it can adjust)
// ask   -> user gets a permission prompt even if an allow rule would match
let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let cmd = '';
  try {
    cmd = JSON.parse(raw)?.tool_input?.command ?? '';
  } catch {
    process.exit(0);
  }

  // Match at start of command or after a shell separator so `pnpm nx` and
  // `NX_DAEMON=false pnpm nx` stay allowed while `npx nx` / bare `nx` are not.
  const atCmdStart = (word) =>
    new RegExp(`(^|[;&|]\\s*|\\$\\(\\s*)(\\w+=\\S*\\s+)*${word}(\\s|$)`);

  const DENY = [
    [/--no-verify\b/, 'Never bypass git hooks (--no-verify). Let pre-commit run.'],
    [atCmdStart('npx\\s+nx'), 'Use `NX_DAEMON=false pnpm nx ...`, never `npx nx` (wrong version).'],
    [atCmdStart('nx'), 'Use `NX_DAEMON=false pnpm nx ...`, never bare `nx`.'],
    [/\bgit\s+add\s+(\.|-A|--all)(\s|$)/, 'Never `git add .`/-A. Stage by file or hunk.'],
  ];

  const ASK = [
    [/\bgit\s+push\b[^;&|]*(\s--force(-with-lease)?\b|\s-f\b)/, 'Force push rewrites remote history.'],
    [/\bgit\s+reset\s+--hard\b/, '`git reset --hard` discards work.'],
    [/\bgit\s+rebase\b/, 'Rebase rewrites history. Only when asked this turn.'],
    [/\bgit\s+commit\b[^;&|]*--amend\b/, 'Amend rewrites history. Only when asked this turn.'],
    [/\bgit\s+branch\s+(-D|--delete\s+--force)\b/, 'Force-deleting a branch.'],
    [/\brm\s+-[a-zA-Z]*(rf|fr)\b/, 'Recursive force delete.'],
    [/\bgit\s+(checkout|restore)\s+(--\s+)?\.(\s|$)/, 'Discards all working-tree changes.'],
  ];

  const respond = (permissionDecision, reason) => {
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision,
          permissionDecisionReason: `[bash-guard] ${reason}`,
        },
      }),
    );
    process.exit(0);
  };

  for (const [re, reason] of DENY) if (re.test(cmd)) respond('deny', reason);
  for (const [re, reason] of ASK) if (re.test(cmd)) respond('ask', reason);
  process.exit(0);
});
