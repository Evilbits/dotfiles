// PostToolUse hook for Edit|Write: format the touched file with the repo's own
// oxfmt (walks up from the file to find node_modules/.bin/oxfmt). No-op when
// the repo doesn't use oxfmt or the file type isn't one it handles.
import { existsSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const EXTS = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.json', '.md', '.css', '.graphql']);

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let file = '';
  try {
    file = JSON.parse(raw)?.tool_input?.file_path ?? '';
  } catch {
    process.exit(0);
  }
  if (!file || !EXTS.has(extname(file)) || !existsSync(file)) process.exit(0);

  let dir = dirname(resolve(file));
  let bin = '';
  while (true) {
    const candidate = join(dir, 'node_modules', '.bin', 'oxfmt');
    if (existsSync(candidate)) { bin = candidate; break; }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  if (!bin) process.exit(0);

  spawnSync(bin, [file], { cwd: dir, stdio: 'ignore', timeout: 15000 });
  process.exit(0);
});
