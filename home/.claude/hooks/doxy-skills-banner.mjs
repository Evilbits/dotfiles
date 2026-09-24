// SessionStart hook (startup, clear): show the /doxy:* skill menu in the transcript, and tell
// Claude to route the first message to the matching skill. Only fires in the doxyme repos, where
// those skills mean something. The skills ship as the "doxy" plugin; this reads the installed copy.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const TAGLINES = {
  design: 'an idea → a brief the team can discuss; ends with the doc and a Shape verdict',
  ticket: 'brief → epic + tickets, a single ticket, or a spike; or reevaluate an existing ticket',
  implement: 'ticket URL → branch, scope, plan, in-session code with tests and atomic commits',
  review: 'an MR or a proposal → architecture-first findings, then comment placement',
  debug: 'a bug report → evidence from Datadog, Slack and the code, a facts checkpoint, a post mortem',
};

// The installed plugin's skills folder: the path Claude recorded at install, else the newest
// version folder in the plugin cache.
function skillsDir() {
  const home = process.env.HOME;
  try {
    const reg = JSON.parse(readFileSync(join(home, '.claude', 'plugins', 'installed_plugins.json'), 'utf8'));
    const entries = (reg.plugins ?? reg)['doxy@rasmus'];
    const p = (Array.isArray(entries) ? entries[0] : entries)?.installPath;
    if (p && existsSync(join(p, 'skills'))) return join(p, 'skills');
  } catch {}
  const cache = join(home, '.claude', 'plugins', 'cache', 'rasmus', 'doxy');
  if (!existsSync(cache)) return null;
  const versions = readdirSync(cache).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
  const last = versions[versions.length - 1];
  return last ? join(cache, last, 'skills') : null;
}

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let cwd = '';
  try { cwd = JSON.parse(raw)?.cwd ?? ''; } catch { process.exit(0); }
  const inDoxyme = /doxyme-core|\/hotpot(\/|$)/.test(cwd);
  const dir = inDoxyme ? skillsDir() : null;
  const skills = dir && existsSync(dir) ? readdirSync(dir).filter((d) => existsSync(join(dir, d, 'SKILL.md'))).sort() : [];
  if (!skills.length) process.exit(0);

  // Fall back to the description's first sentence for a skill without a tagline.
  const tagline = (name) => {
    if (TAGLINES[name]) return TAGLINES[name];
    const md = readFileSync(join(dir, name, 'SKILL.md'), 'utf8');
    const desc = (md.match(/description:\s*>-?\s*([\s\S]*?)\n---/) ?? [])[1] ?? '';
    return desc.replace(/\s+/g, ' ').trim().split(/(?<=\.)\s/)[0].slice(0, 110);
  };

  const width = skills.length ? Math.max(...skills.map((s) => s.length)) + 1 : 0;
  const lines = skills.map((s) => `  /doxy:${s.padEnd(width)} ${tagline(s)}`);
  const skillBlock = skills.length ? ['Doxyme workflow skills:', ...lines] : [];
  const systemMessage = skillBlock.join('\n');
  const additionalContext = skills.length
    ? `The user has workflow skills for this repo: ${skills.map((s) => '/doxy:' + s).join(', ')}. ` +
      'They will forget to type them. When the first message matches one of them, invoke that skill; ' +
      'when it plausibly matches one, name the matching skill in one line before answering.'
    : '';

  process.stdout.write(JSON.stringify({ systemMessage, hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext } }));
});
