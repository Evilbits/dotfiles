/**
 * Shared title-generation prompt, normalization, and CLI invocation.
 * Keep the hook fallback and the CLI backfill logic aligned.
 */

import { spawn } from "child_process";
import { existsSync, mkdirSync, rmSync } from "fs";
import { join } from "path";
import { homedir, tmpdir } from "os";

const TITLE_PROMPT_RULES = `Rules:
- If the conversation mentions a Jira-style ticket ID (uppercase letters + dash + digits, e.g. PROD-1234, FOO-42), format as: "PROD-1234: <short recap>" — keep the ID in UPPERCASE, colon, single space, then a recap of max 50 characters
- Otherwise, just write a short recap of the conversation, max 50 characters
- The recap is plain English (NOT kebab-case). Capitalize the first letter, no trailing period.
- Be SPECIFIC: mention the actual technology, feature, file, or bug
- When fitting the recap into the character limit, prioritize distinctive terms (class names, file names, technologies, identifiers like "ApplicationService") over filler words ("the", "in", "of", "with"). Reword the sentence if needed — drop articles and prepositions before dropping specific terms.
- Focus on WHAT was done, not how the conversation started
- Never include URLs, file paths, or generic words like "help", "work", "session", "project"
- Good: "PROD-7697: Fix entitlement filter", "FOO-42: Refactor auth middleware", "Fix stripe webhook retry"
- Bad: "coding-session", "helping-with-code", "PROD-7697: helping with code"`;

// Dedicated temp directory for claude -p worker sessions.
// Sessions created here are cleaned up after each call so they
// never appear in the user's `claude --resume` list.
const WORKER_CWD = join(tmpdir(), "claude-rename-worker");

export function buildTitlePrompt(userMessages, assistantMessages, options = {}) {
  const {
    replyInstruction = "Reply with ONLY the title, nothing else",
    includeQuotesNote = false,
  } = options;

  const userContext = userMessages.slice(0, 3).join("\n\n").slice(0, 1500);
  const assistantContext = assistantMessages
    .slice(0, 1)
    .join("\n")
    .slice(0, 500);

  const replyLine = includeQuotesNote
    ? `${replyInstruction} — no explanation, no quotes`
    : replyInstruction;

  return `You generate short session titles for Claude Code conversations.

${TITLE_PROMPT_RULES}
- ${replyLine}

User messages:
${userContext}

Assistant response:
${assistantContext}

Title:`;
}

export function normalizeGeneratedTitle(rawOutput) {
  if (typeof rawOutput !== "string") return null;

  let title = rawOutput.trim();
  const lines = title.split("\n").filter((line) => line.trim());
  if (lines.length > 0) {
    title = lines[lines.length - 1].trim();
  }

  title = title
    .replace(/^[`'"*]+|[`'"*]+$/g, "")
    .replace(/[.\s]+$/, "")
    .trim();

  const STOPWORDS = new Set(["a","an","and","at","be","but","by","for","from","in","is","of","on","or","the","this","that","to","was","with"]);
  const dropTrailingStopwords = (s) => {
    const words = s.split(/\s+/);
    while (words.length > 1 && STOPWORDS.has(words[words.length - 1].toLowerCase())) {
      words.pop();
    }
    return words.join(" ");
  };

  const jiraMatch = title.match(/^([A-Z]+-[0-9]+)\s*[:\-]?\s*(.*)$/);
  if (jiraMatch && jiraMatch[2].trim()) {
    const jiraId = jiraMatch[1];
    let recap = jiraMatch[2].trim();
    if (recap.length > 50) {
      recap = recap.slice(0, 50);
      const lastSpace = recap.lastIndexOf(" ");
      if (lastSpace > 10) recap = recap.slice(0, lastSpace);
    }
    recap = dropTrailingStopwords(recap);
    title = `${jiraId}: ${recap}`;
  } else if (title.length > 50) {
    title = title.slice(0, 50);
    const lastSpace = title.lastIndexOf(" ");
    if (lastSpace > 20) title = title.slice(0, lastSpace);
    title = dropTrailingStopwords(title);
  }

  if (title.length >= 5 && title.length <= 70) return title;
  return null;
}

/**
 * Run `claude -p --model <model>` with the given prompt piped via stdin.
 * Runs from a temp directory and cleans up the session file afterwards
 * so worker sessions never appear in the user's `claude --resume` list.
 *
 * @param {string} prompt - The prompt to send
 * @param {string} model - Model name (e.g. "haiku", "sonnet")
 * @returns {Promise<string|null>} Normalized kebab-case title, or null
 */
export function generateTitleViaCLI(prompt, model) {
  mkdirSync(WORKER_CWD, { recursive: true });

  return new Promise((resolve) => {
    let stdout = "";
    let settled = false;

    const child = spawn("claude", ["-p", "--model", model], {
      cwd: WORKER_CWD,
      stdio: ["pipe", "pipe", "pipe"],
    });

    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        child.kill();
        cleanupWorkerSessions();
        resolve(null);
      }
    }, 30000);

    child.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    child.on("close", () => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        cleanupWorkerSessions();
        resolve(normalizeGeneratedTitle(stdout));
      }
    });

    child.on("error", () => {
      if (!settled) {
        settled = true;
        clearTimeout(timer);
        cleanupWorkerSessions();
        resolve(null);
      }
    });

    child.stdin.write(prompt);
    child.stdin.end();
  });
}

/**
 * Remove session files created by `claude -p` in the worker directory.
 * The project directory is derived from WORKER_CWD the same way Claude Code
 * encodes cwd paths: replace / with -.
 */
function cleanupWorkerSessions() {
  try {
    const encoded = WORKER_CWD.replace(/\//g, "-");
    const projectDir = join(homedir(), ".claude", "projects", encoded);
    if (existsSync(projectDir)) {
      rmSync(projectDir, { recursive: true, force: true });
    }
  } catch {}
}
