// SessionStart hook (startup, clear): show the personal /doxy-* skill menu in
// the transcript, and tell Claude to route the first message to the matching
// skill. Only fires in the doxyme repos, where those skills mean something.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const TAGLINES = {
  'doxy-design': 'an idea → a brief the team can discuss; ends with the doc and a Shape verdict',
  'doxy-ticket': 'brief → epic + tickets, a single ticket, or a spike; or reevaluate an existing ticket',
  'doxy-implement': 'ticket URL → branch, scope, plan, in-session code with tests and atomic commits',
  'doxy-review': 'an MR or a proposal → architecture-first findings, then comment placement',
};

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let cwd = '';
  try { cwd = JSON.parse(raw)?.cwd ?? ''; } catch { process.exit(0); }
  if (!/doxyme-core|\/hotpot(\/|$)/.test(cwd)) process.exit(0);

  const skillsDir = join(process.env.HOME, '.claude', 'skills');
  if (!existsSync(skillsDir)) process.exit(0);
  const skills = readdirSync(skillsDir).filter((d) => d.startsWith('doxy-') && existsSync(join(skillsDir, d, 'SKILL.md'))).sort();
  if (!skills.length) process.exit(0);

  // Fall back to the description's first sentence for a skill without a tagline.
  const tagline = (name) => {
    if (TAGLINES[name]) return TAGLINES[name];
    const md = readFileSync(join(skillsDir, name, 'SKILL.md'), 'utf8');
    const desc = (md.match(/description:\s*>-?\s*([\s\S]*?)\n---/) ?? [])[1] ?? '';
    return desc.replace(/\s+/g, ' ').trim().split(/(?<=\.)\s/)[0].slice(0, 110);
  };

  const width = Math.max(...skills.map((s) => s.length)) + 1;
  const lines = skills.map((s) => `  /${s.padEnd(width)} ${tagline(s)}`);
  const systemMessage = ['Personal skills for doxyme:', ...lines].join('\n');
  const additionalContext =
    `The user has personal skills for this repo: ${skills.map((s) => '/' + s).join(', ')}. ` +
    'They will forget to type them. When the first message matches one of them, invoke that skill; ' +
    'when it plausibly matches one, name the matching skill in one line before answering.';

  process.stdout.write(JSON.stringify({ systemMessage, hookSpecificOutput: { hookEventName: 'SessionStart', additionalContext } }));
});
