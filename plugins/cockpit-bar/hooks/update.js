#!/usr/bin/env node
// Maps a Claude Code hook event to this session's file: ~/.local/state/cockpit/bar/state.d/<session_id>.json
// Usage: node update.js <prompt|pre|post|notify|permreq|stop>
// Adapted from claude-status-bar (MIT, m1ckc3s): only the paths, the app name and the tool labels changed.

const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const BUNDLE_ID = "com.rasmusreiler.cockpit-bar";
const EXEC = "CockpitBar";
const dir = path.join(os.homedir(), ".local", "state", "cockpit", "bar");
const stateDir = path.join(dir, "state.d");
// Written by the app's Quit menu item; suppresses the relaunch below so Quit sticks.
// lifecycle.js removes it on the next SessionStart (a new session = fresh consent).
const quitMarker = path.join(dir, "quit-intent");
const event = process.argv[2] || "";

const TOOL_LABELS = {
  Bash: "Running command", Edit: "Editing", Write: "Writing", MultiEdit: "Editing",
  NotebookEdit: "Editing", Read: "Reading", Grep: "Searching", Glob: "Searching",
  WebFetch: "Browsing web", WebSearch: "Searching web", Task: "Delegating", Agent: "Delegating",
  TodoWrite: "Planning", AskUserQuestion: "Asking you", Skill: "Loading a skill",
};

const safeId = (s) => String(s || "").replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 64) || "unknown";

let raw = "";
process.stdin.on("data", (d) => (raw += d));
process.stdin.on("end", () => {
  let p = {};
  try { p = JSON.parse(raw || "{}"); } catch {}

  // This session's own file is the unit of state AND the liveness marker. Writing it on any
  // event also tracks sessions that predate the hook install (never fired SessionStart).
  const sid = safeId(p.session_id);
  const statePath = path.join(stateDir, sid + ".json");

  let prev = {};
  try { prev = JSON.parse(fs.readFileSync(statePath, "utf8")); } catch {}

  const project = p.cwd ? path.basename(p.cwd) : prev.project || "";
  const cwd = p.cwd || prev.cwd || "";
  const ts = Math.floor(Date.now() / 1000);
  let state = "idle", label = "", startedAt = prev.startedAt || 0;

  switch (event) {
    case "prompt":
      state = "thinking"; label = "Thinking…"; startedAt = ts; break;
    case "pre": {
      const t = p.tool_name || "";
      state = "tool"; label = TOOL_LABELS[t] || (t.startsWith("mcp__") ? "Calling " + t.split("__")[1] : "Using tool");
      if (!startedAt) startedAt = ts;
      break;
    }
    case "post":
      state = "thinking"; label = "Thinking…";
      if (!startedAt) startedAt = ts;
      break;
    case "notify": {
      // Only a permission prompt drives the icon here. Ignore every other Notification (esp. the
      // idle_prompt "Claude is waiting for your input") so the icon rests instead of parking on it.
      const m = (p.message || "").toLowerCase();
      const isPerm = p.notification_type === "permission_prompt" ||
        m.includes("permission") || m.includes("approve") || m.includes("allow");
      if (!isPerm) return;
      state = "permission"; label = "Awaiting permission"; startedAt = 0;
      break;
    }
    case "permreq":
      state = "permission"; label = "Awaiting permission"; startedAt = 0; break;
    case "stop":
      state = "done"; label = "Done"; startedAt = 0; break;
    default:
      return;
  }

  const entrypoint = process.env.CLAUDE_CODE_ENTRYPOINT || prev.entrypoint || "";
  const termProgram = process.env.TERM_PROGRAM || prev.term_program || "";
  // process.ppid IS this session's `claude` process (hooks are spawned directly by it, stable for the
  // session's life). The app uses kill(pid,0) for liveness.
  const out = { state, label, tool: p.tool_name || "", project, cwd, sessionId: p.session_id || "", transcript: p.transcript_path || prev.transcript || "", entrypoint, term_program: termProgram, pid: process.ppid, started: true, startedAt, ts };
  try {
    fs.mkdirSync(stateDir, { recursive: true });
    const tmp = statePath + "." + process.pid + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(out));
    fs.renameSync(tmp, statePath);
  } catch {}

  // Self-heal: a session with live state but no app to show it relaunches the app. Skipped after an
  // explicit menu Quit.
  try {
    if (!fs.existsSync(quitMarker)) {
      cp.execSync(`pgrep -x ${EXEC}`, { stdio: "ignore" });
    }
  } catch {
    try { cp.spawn("open", ["-g", "-b", BUNDLE_ID], { stdio: "ignore", detached: true }).unref(); } catch {}
  }
});
