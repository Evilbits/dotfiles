#!/usr/bin/env node

/**
 * Claude Code Session Auto-Namer — Stop Hook
 *
 * Fires after each assistant turn. On the first meaningful exchange of a
 * new session, spawns a background worker that names it via `claude -p`.
 *
 * No separate API key needed — uses your existing Claude Code subscription.
 * Always outputs { continue: true, suppressOutput: true } so the user
 * never sees any hook output.
 *
 * Flow:
 *   Stop fires → session needs naming? → spawn background `claude -p` worker
 *   Worker generates title → writes to JSONL → marks done
 *
 * Install: claude-rename install
 * This file is copied to ~/.claude/hooks/ together with title-prompt.mjs.
 */

import {
  readFileSync,
  writeFileSync,
  appendFileSync,
  existsSync,
  mkdirSync,
  realpathSync,
} from "fs";
import { join } from "path";
import { homedir } from "os";
import { fileURLToPath } from "url";
import { spawn } from "child_process";
import { buildTitlePrompt, generateTitleViaCLI, normalizeGeneratedTitle } from "./title-prompt.mjs";

const MARKER_DIR = join(homedir(), ".claude", ".session-namer-named");
const MAX_ATTEMPTS = 3;
const LOG_FILE = join(homedir(), ".claude-rename.log");

// ─── Background Worker Mode ─────────────────────────────────────────────────
// When invoked with --name, we're the background worker doing AI naming via claude -p.

if (process.argv.includes("--name")) {
  const idx = process.argv.indexOf("--name");
  const sessionId = process.argv[idx + 1];
  const jsonlPath = process.argv[idx + 2];

  if (sessionId && jsonlPath) {
    try {
      await nameSessionAI(sessionId, jsonlPath);
    } catch (err) {
      log(`Worker error for ${sessionId}: ${err.message}`);
    }
  }
  process.exit(0);
}

// ─── Hook Mode (stdin) ──────────────────────────────────────────────────────

async function main() {
  try {
    const input = await readStdin();
    let data = {};
    try {
      data = JSON.parse(input);
    } catch {
      output();
      return;
    }

    const sessionId = data.sessionId || data.session_id || "";
    const cwd = data.cwd || data.directory || "";
    if (data.stop_hook_active) {
      output();
      return;
    }

    const stopReason = (
      data.stop_reason ||
      data.stopReason ||
      ""
    ).toLowerCase();

    // Never block context-limit, abort, or cancel stops
    if (
      stopReason.includes("context") ||
      stopReason.includes("abort") ||
      stopReason.includes("cancel")
    ) {
      output();
      return;
    }

    if (!sessionId || !cwd) {
      output();
      return;
    }

    const markerPath = join(MARKER_DIR, sessionId);
    const jsonlPath =
      resolveTranscriptPath(data.transcript_path || data.transcriptPath) ||
      getSessionJsonlPath(cwd, sessionId);

    if (!existsSync(jsonlPath)) {
      output();
      return;
    }

    // Marker drives behavior. Claude Code's built-in auto-namer also writes
    // custom-title records, so we don't trust the jsonl — we trust our marker.
    const marker = readMarkerContent(markerPath);

    // User explicitly /rename'd? Adopt that as the authoritative title.
    const userRename = findLatestRename(jsonlPath);
    if (userRename && userRename !== marker.title) {
      writeFileSync(markerPath, userRename);
      writeTitle(jsonlPath, sessionId, userRename);
      output();
      return;
    }

    // A conversation resumed under a new id keeps the title it already had instead of being named
    // afresh: either the old transcript's records come along, stamped with the old id, or Claude
    // starts the new transcript with the old title as its own custom-title record.
    if (marker.status === "absent") {
      const inherited = findAncestorTitle(jsonlPath, sessionId) || findCarriedTitle(jsonlPath);
      if (inherited) {
        markDone(markerPath, inherited);
        writeTitle(jsonlPath, sessionId, inherited);
        output();
        return;
      }
    }

    // Already named: re-append our title so it's the last custom-title record
    // in the file (the picker reads the last one — last write wins).
    if (marker.status === "named") {
      writeTitle(jsonlPath, sessionId, marker.title);
      output();
      return;
    }

    // Worker already running, or previously failed — don't spawn again. A title that said nothing
    // leaves "retry-N" and is tried again on a later Stop, when the transcript knows more.
    if (
      marker.status === "naming" ||
      marker.status === "failed" ||
      (marker.status === "retry" && marker.attempts >= MAX_ATTEMPTS)
    ) {
      output();
      return;
    }

    // Not enough conversation yet? Skip.
    if (!hasMinimalConversation(jsonlPath)) {
      output();
      return;
    }

    // ── Spawn background AI naming worker ──
    mkdirSync(MARKER_DIR, { recursive: true });
    writeFileSync(markerPath, `naming-${(marker.attempts || 0) + 1}`);
    log(`Spawning background namer for ${sessionId}`);

    const child = spawn(
      process.execPath,
      [process.argv[1], "--name", sessionId, jsonlPath],
      { detached: true, stdio: "ignore" },
    );
    child.unref();

    output();
  } catch {
    output();
  }
}

// ─── AI Naming (background worker via claude -p) ────────────────────────────

async function nameSessionAI(sessionId, jsonlPath) {
  if (isMarkerDone(join(MARKER_DIR, sessionId))) return;

  const markerPath = join(MARKER_DIR, sessionId);
  const attempts = readMarkerContent(markerPath).attempts || 1;
  const { userMessages, assistantMessages } = extractMessages(jsonlPath);
  if (userMessages.length === 0) return;

  const ticket = findTicket(jsonlPath, userMessages[0]);
  const model = getConfigModel();
  let title = await generateTitleViaClaude(userMessages, model, assistantMessages, ticket);
  if (title && saysNothing(title)) {
    log(`Rejected empty title for ${sessionId}: "${title}"`);
    title = null;
  }
  // The user may have /rename'd while the worker ran; their name wins, and it must stay the last
  // custom-title record, so never append a generated one over it.
  const userRename = findLatestRename(jsonlPath);
  if (userRename) {
    markDone(join(MARKER_DIR, sessionId), userRename);
    writeTitle(jsonlPath, sessionId, userRename);
    log(`Kept user rename: ${sessionId} → "${userRename}"`);
    return;
  }
  if (title) {
    writeTitle(jsonlPath, sessionId, title);
    markDone(join(MARKER_DIR, sessionId), title);
    log(`Named (${model}): ${sessionId} → "${title}"`);
    return;
  }

  if (ticket?.summary) {
    const fromTicket = normalizeGeneratedTitle(`${ticket.key}: ${ticket.summary.replace(/^\[[^\]]*\]\s*/, "")}`);
    if (fromTicket) {
      writeTitle(jsonlPath, sessionId, fromTicket);
      markDone(markerPath, fromTicket);
      log(`Named (ticket): ${sessionId} → "${fromTicket}"`);
      return;
    }
  }

  if (attempts < MAX_ATTEMPTS) {
    markRetry(markerPath, attempts);
    log(`Retry later for ${sessionId} (attempt ${attempts})`);
    return;
  }

  const fallback = extractFallbackTitle(userMessages);
  if (fallback) {
    writeTitle(jsonlPath, sessionId, fallback);
    markDone(join(MARKER_DIR, sessionId), fallback);
    log(`Named (fallback): ${sessionId} → "${fallback}"`);
  } else {
    markFailed(join(MARKER_DIR, sessionId));
    log(`Failed to generate title for ${sessionId}`);
  }
}

function extractFallbackTitle(userMessages) {
  const first = userMessages[0] || "";
  const ticket = first.match(/\b[A-Z]+-\d+\b/);
  if (ticket) return ticket[0];
  const cleaned = first
    .replace(/https?:\/\/\S+/g, "")
    .replace(/[^a-zA-Z0-9\s-]/g, " ")
    .trim();
  const words = cleaned.split(/\s+/).filter((w) => w.length > 1).slice(0, 6);
  const title = words.join(" ").slice(0, 60).trim();
  return title.length >= 5 ? title : null;
}

export function getConfigModel() {
  try {
    const configPath = join(homedir(), ".claude-rename.json");
    const config = JSON.parse(readFileSync(configPath, "utf-8"));
    return config.model || "haiku";
  } catch {
    return "haiku";
  }
}

/**
 * The Jira ticket the session opened on, with its summary when a Jira tool result in the transcript
 * carries it. A session started as "/doxy-apps:implement <ticket URL>" says nothing else about its
 * subject, and the worker has no network, so the ticket's own title is read from what the session
 * already fetched.
 */
function findTicket(jsonlPath, firstMessage) {
  const key = (firstMessage || "").match(/\b[A-Z][A-Z0-9]+-\d+\b/)?.[0];
  if (!key) return null;
  try {
    const lines = readFileSync(jsonlPath, "utf-8").split("\n");
    for (const line of lines) {
      if (!line.includes("tool_result") || !line.includes(key)) continue;
      let entry;
      try { entry = JSON.parse(line); } catch { continue; }
      const content = entry.message?.content;
      if (!Array.isArray(content)) continue;
      for (const part of content) {
        if (part.type !== "tool_result") continue;
        const text = typeof part.content === "string"
          ? part.content
          : Array.isArray(part.content) ? part.content.map((c) => c.text || "").join("") : "";
        const summary = findIssueSummary(text, key);
        if (summary) return { key, summary };
      }
    }
  } catch {}
  return { key, summary: null };
}

function findIssueSummary(text, key) {
  if (!text.includes(`"${key}"`)) return null;
  let data;
  try { data = JSON.parse(text); } catch { return null; }
  const stack = [data];
  while (stack.length) {
    const node = stack.pop();
    if (!node || typeof node !== "object") continue;
    if (node.key === key && typeof node.fields?.summary === "string") return node.fields.summary;
    stack.push(...Object.values(node));
  }
  return null;
}

// A title that is only the ticket and the skill's verb ("PROD-11674: Implement") names nothing;
// cockpit strips the ID and shows the verb as a pill already.
function saysNothing(title) {
  const recap = title.replace(/^[A-Z][A-Z0-9]+-\d+:\s*/, "").trim().toLowerCase();
  return /^(doxy(-apps)?[: -])?(implement|review|design|debug|ticket|feature|vibe[- ]app|snooze)( ticket)?$/.test(recap);
}

function generateTitleViaClaude(userMessages, model, assistantMessages = [], ticket = null) {
  const prompt = buildTitlePrompt(userMessages, {
    replyInstruction: "Reply with ONLY the title, nothing else",
    assistantMessages,
    ticket,
  });
  return generateTitleViaCLI(prompt, model, ({ reason, stdout, stderr, code }) => {
    log(
      `Worker rejected (${reason}, code=${code}) stdout=${JSON.stringify((stdout || "").slice(0, 200))} stderr=${JSON.stringify((stderr || "").slice(0, 200))}`,
    );
  });
}

// ─── Stdin Reader ────────────────────────────────────────────────────────────

function readStdin(timeoutMs = 3000) {
  return new Promise((resolve) => {
    const chunks = [];
    let settled = false;
    const done = (val) => {
      if (!settled) {
        settled = true;
        resolve(val);
      }
    };
    const timeout = setTimeout(() => {
      process.stdin.removeAllListeners();
      done(Buffer.concat(chunks).toString("utf-8"));
    }, timeoutMs);
    process.stdin.on("data", (chunk) => chunks.push(chunk));
    process.stdin.on("end", () => {
      clearTimeout(timeout);
      done(Buffer.concat(chunks).toString("utf-8"));
    });
    process.stdin.on("error", () => {
      clearTimeout(timeout);
      done("");
    });
    if (process.stdin.readableEnded) {
      clearTimeout(timeout);
      done(Buffer.concat(chunks).toString("utf-8"));
    }
  });
}

// ─── Path Utilities ──────────────────────────────────────────────────────────

function resolveTranscriptPath(transcriptPath) {
  if (!transcriptPath || typeof transcriptPath !== "string") return null;
  if (transcriptPath.startsWith("~")) {
    return join(homedir(), transcriptPath.slice(2));
  }
  return transcriptPath;
}

function cwdToProjectDir(cwd) {
  return cwd.replace(/\//g, "-");
}

function getSessionJsonlPath(cwd, sessionId) {
  const encoded = cwdToProjectDir(cwd);
  return join(homedir(), ".claude", "projects", encoded, `${sessionId}.jsonl`);
}

// ─── Idempotency ─────────────────────────────────────────────────────────────

function readMarkerContent(markerPath) {
  try {
    const content = readFileSync(markerPath, "utf-8").trim();
    if (!content || content === "naming") return { status: "naming" };
    const pending = content.match(/^(naming|retry)-(\d+)$/);
    if (pending) return { status: pending[1], attempts: Number(pending[2]) };
    if (content === "failed") return { status: "failed" };
    if (content === "done") return { status: "stale" }; // legacy marker, regenerate
    return { status: "named", title: content };
  } catch {
    return { status: "absent" };
  }
}

function isMarkerDone(markerPath) {
  return readMarkerContent(markerPath).status === "named";
}

function markDone(markerPath, title) {
  try {
    mkdirSync(MARKER_DIR, { recursive: true });
    writeFileSync(markerPath, title);
  } catch {}
}

function markRetry(markerPath, attempts) {
  try {
    mkdirSync(MARKER_DIR, { recursive: true });
    writeFileSync(markerPath, `retry-${attempts}`);
  } catch {}
}

function markFailed(markerPath) {
  try {
    mkdirSync(MARKER_DIR, { recursive: true });
    writeFileSync(markerPath, "failed");
  } catch {}
}

// ─── Conversation Extraction ─────────────────────────────────────────────────

function findLatestRename(jsonlPath) {
  try {
    const lines = readFileSync(jsonlPath, "utf-8").split("\n");
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i];
      if (!line.includes('"local_command"') || !line.includes("/rename")) continue;
      try {
        const entry = JSON.parse(line);
        if (entry.type !== "system" || entry.subtype !== "local_command") continue;
        const content = entry.content || "";
        if (!content.includes("<command-name>/rename</command-name>")) continue;
        const m = content.match(/<command-args>([\s\S]*?)<\/command-args>/);
        if (m && m[1].trim()) return m[1].trim();
      } catch {}
    }
    return null;
  } catch {
    return null;
  }
}

/** The title of the latest earlier session id in this transcript that has one; later ids win. */
// The first custom-title record in a transcript this hook has not named yet: Claude wrote it
// there when it resumed the conversation under this new id.
function findCarriedTitle(jsonlPath) {
  try {
    for (const line of readFileSync(jsonlPath, "utf-8").split("\n")) {
      if (!line.includes('"type":"custom-title"')) continue;
      const title = JSON.parse(line).customTitle;
      if (title && title.trim()) return title.trim();
    }
  } catch {}
  return null;
}

function findAncestorTitle(jsonlPath, sessionId) {
  let title = null;
  try {
    const seen = new Set();
    for (const line of readFileSync(jsonlPath, "utf-8").split("\n")) {
      const m = line.match(/^\{[^\n]*?"sessionId":"([0-9a-f-]{36})"/);
      if (!m || m[1] === sessionId || seen.has(m[1])) continue;
      seen.add(m[1]);
      const ancestor = readMarkerContent(join(MARKER_DIR, m[1]));
      if (ancestor.status === "named") title = ancestor.title;
    }
  } catch {}
  return title;
}

function hasMinimalConversation(jsonlPath) {
  try {
    const lines = readFileSync(jsonlPath, "utf-8").split("\n");
    let hasUser = false;
    let hasAssistant = false;
    for (const line of lines) {
      if (!line) continue;
      try {
        const entry = JSON.parse(line);
        if (entry.type === "user" && entry.message?.content) {
          const text = extractText(entry.message.content);
          if (text && !isSystemMessage(text)) hasUser = true;
        }
        if (entry.type === "assistant" && entry.message?.content) {
          hasAssistant = true;
        }
      } catch {}
      if (hasUser && hasAssistant) return true;
    }
    return false;
  } catch {
    return false;
  }
}

function extractMessages(jsonlPath) {
  const userMessages = [];
  const assistantMessages = [];

  try {
    const lines = readFileSync(jsonlPath, "utf-8").split("\n");
    for (const line of lines) {
      if (!line) continue;
      try {
        const entry = JSON.parse(line);
        if (entry.type === "user" && entry.message?.content) {
          const text = extractText(entry.message.content);
          if (text && !isSystemMessage(text)) {
            userMessages.push(text);
          }
        } else if (entry.type === "assistant" && entry.message?.content) {
          const text = extractText(entry.message.content);
          if (text) assistantMessages.push(text);
        }
      } catch {}
    }
  } catch {}

  return { userMessages, assistantMessages };
}

function extractText(content) {
  let text = "";
  if (typeof content === "string") text = content;
  else if (Array.isArray(content)) {
    text = content
      .filter((c) => c.type === "text")
      .map((c) => c.text)
      .join(" ");
  }
  // A skill invocation arrives as "<command-name>/x</command-name><command-args>…</command-args>";
  // the command and its arguments (an MR link, a ticket) are what the session is about.
  const cmd = text.match(/<command-name>([^<]+)<\/command-name>/);
  if (cmd) {
    const args = text.match(/<command-args>([\s\S]*?)<\/command-args>/);
    return (cmd[1].trim() + " " + (args ? args[1].trim() : "")).trim();
  }
  return text;
}

function isSystemMessage(text) {
  return (
    text.startsWith("<local-command-caveat>") ||
    text.startsWith("<system-reminder>") ||
    // The body of a skill, injected as a user message when a skill is invoked.
    text.startsWith("Base directory for this skill") ||
    /^<[a-z-]+>/.test(text.trim())
  );
}

// ─── JSONL Writer ────────────────────────────────────────────────────────────

function writeTitle(jsonlPath, sessionId, title) {
  const entry = JSON.stringify({
    type: "custom-title",
    customTitle: title,
    sessionId,
  });
  appendFileSync(jsonlPath, entry + "\n");
}

// ─── Logging ─────────────────────────────────────────────────────────────────

function log(msg) {
  try {
    const ts = new Date().toISOString();
    appendFileSync(LOG_FILE, `${ts} ${msg}\n`);
  } catch {}
}

// ─── Output ──────────────────────────────────────────────────────────────────

function output() {
  process.stdout.write(JSON.stringify({ continue: true, suppressOutput: true }) + "\n");
}

// ─── Entry ───────────────────────────────────────────────────────────────────

if (process.argv[1]) {
  let invokedPath = process.argv[1];
  try { invokedPath = realpathSync(process.argv[1]); } catch {}
  if (fileURLToPath(import.meta.url) === invokedPath) {
    main();
  }
}
