#!/usr/bin/env sh
# forged-in-prod starter — one-shot installer.
#   Installs minimal WORKLOG automation + pending-decision surfacing into a project.
#   Usage:  sh install.sh [target-dir]      (default target: current directory)
#
# Idempotent and fail-safe by design:
#   - never overwrites an existing CLAUDE.md, WORKLOG.md, or settings.json
#   - re-running only fills in what's missing
#   - the hook it installs is fail-open (no git / no python / any error -> silent)
# Uninstall = delete the marked block in CLAUDE.md, the .claude/hooks file, and
# the Stop hook line in settings.json. Nothing here touches anything else.
set -eu

TARGET="${1:-.}"
cd "$TARGET" 2>/dev/null || { echo "target dir not found: $TARGET" >&2; exit 1; }
TARGET="$(pwd)"
echo "forged-in-prod starter -> $TARGET"

CLAUDE="CLAUDE.md"
WORKLOG="WORKLOG.md"
HOOKDIR=".claude/hooks"
HOOK="$HOOKDIR/worklog_reminder.py"
SETTINGS=".claude/settings.json"
MARK="<!-- forged-in-prod:rules -->"

# ---- 1) CLAUDE.md rules (the part that actually works: in context every turn) ----
if [ -f "$CLAUDE" ] && grep -qF "$MARK" "$CLAUDE" 2>/dev/null; then
  echo "  [skip] CLAUDE.md already has the rules"
else
  [ -f "$CLAUDE" ] && printf '\n' >> "$CLAUDE"
  cat >> "$CLAUDE" <<'__CLAUDE__'
<!-- forged-in-prod:rules -->
## Task ledger (WORKLOG.md)

Keep exactly one `WORKLOG.md` at the repo root as the single task ledger.

- **Touch code → append an entry.** No code touched, no entry.
- Each entry records only two things: **the goal** (what this work must deliver)
  and **where things stand** — including **verification evidence** (what command
  ran, what output appeared) and **the next step**.
- After a context compaction or a new session, **read the latest WORKLOG entry
  first** and continue from it. Do not re-investigate facts already verified there.
- Never create a second progress doc. One ledger, or none.

Quality bar: a fresh agent with zero context must be able to resume from the
latest entry alone. "Done" with no evidence line is not done.

## Surfacing decisions only the user can make

When you hit a blocker whose root cause is a decision only the user can make
(not something you can resolve yourself), do two things: record it where it
belongs, AND append one line to the fixed "⏳ Awaiting your decision" section at
the very top of `WORKLOG.md` (between the header note and the first log entry) —
date, what's blocked, the one-sentence decision, and where the evidence is. That
section is pinned above the log stream so it never scrolls away. Strike the line
once the decision lands. Only user-decidable blockers go here; anything you can
resolve yourself does not.
<!-- /forged-in-prod:rules -->
__CLAUDE__
  echo "  [ok]   appended rules to CLAUDE.md"
fi

# ---- 2) WORKLOG.md skeleton (only if absent; never clobber an existing ledger) ----
if [ -f "$WORKLOG" ]; then
  echo "  [skip] WORKLOG.md exists (left untouched)"
else
  cat > "$WORKLOG" <<'__WORKLOG__'
# WORKLOG

> Newest entry on top. See CLAUDE.md for the ledger rules.

## ⏳ Awaiting your decision (ball in your court)
> When a blocker needs a decision only you can make, an entry lands here and stays
> pinned above the log stream. Empty = nothing is waiting on you.

<!-- format: - [ ] [YYYY-MM-DD] what's blocked — the one-sentence decision — where the evidence is -->

---

<!-- log entries below, newest first -->
__WORKLOG__
  echo "  [ok]   created WORKLOG.md"
fi

# ---- 3) the backstop hook (fail-open, zero deps, no dead-loop) ----
mkdir -p "$HOOKDIR"
cat > "$HOOK" <<'__HOOK__'
#!/usr/bin/env python3
"""
WORKLOG reminder — a Claude Code `Stop` hook.

Fires when the agent tries to end its turn. If the git working tree has code
changes but WORKLOG.md was NOT touched this turn, it blocks the stop once and
tells the agent to record an entry. Otherwise it stays silent.

Design rules:
  - FAIL-OPEN: any error, missing git, missing python feature -> exit 0, never
    trap the user. A reminder hook must never be able to wedge a session.
  - NO DEAD-LOOP: honours `stop_hook_active` so it reminds at most once.
  - ZERO DEPENDENCIES: standard library only.
"""
import json
import subprocess
import sys
from pathlib import Path

WORKLOG_NAME = "WORKLOG.md"


def git(root, *args):
    out = subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        text=True,
        timeout=5,
    )
    return out.stdout


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # fail-open: can't parse -> let the turn end

    if payload.get("stop_hook_active"):
        return 0  # already reminded once this turn -> don't loop

    try:
        root = git(None, "rev-parse", "--show-toplevel").strip()
        if not root:
            return 0  # not a git repo -> nothing to compare against
        root = Path(root)

        changed = set()
        for line in git(root, "status", "--porcelain").splitlines():
            path = line[3:].strip().strip('"')
            if " -> " in path:  # renames: "old -> new"
                path = path.split(" -> ", 1)[1]
            if path:
                changed.add(path)

        worklog_touched = any(Path(p).name == WORKLOG_NAME for p in changed)
        code_changed = any(Path(p).name != WORKLOG_NAME for p in changed)

        if code_changed and not worklog_touched:
            reason = (
                "This turn changed code but WORKLOG.md was not updated. "
                "Before ending, append one entry: the goal, where things stand "
                "(with verification evidence — what command ran, what you saw), "
                "and the next step. If nothing substantive was done, ignore this."
            )
            print(json.dumps({"decision": "block", "reason": reason}))
            return 0
    except Exception:
        return 0  # fail-open on anything unexpected

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
__HOOK__
echo "  [ok]   installed $HOOK"

# ---- 4) settings.json (create fresh, or merge the Stop hook into an existing one) ----
mkdir -p .claude
if [ -f "$SETTINGS" ]; then
  # Pick a python that actually RUNS. On Windows, `command -v python3` often finds
  # the Microsoft Store app-execution-alias stub, which is not a working python —
  # so we test `-c "import sys"` and skip anything that fails.
  PY=""
  for cand in python3 python py; do
    p="$(command -v "$cand" 2>/dev/null || true)"
    if [ -n "$p" ] && "$p" -c "import sys" >/dev/null 2>&1; then PY="$p"; break; fi
  done
  if [ -n "$PY" ]; then
    if "$PY" - "$SETTINGS" <<'__PYMERGE__'
import json, sys
p = sys.argv[1]
try:
    cfg = json.load(open(p, encoding="utf-8-sig"))  # utf-8-sig: tolerate a BOM
    if not isinstance(cfg, dict):
        raise ValueError
except Exception:
    print("  [!]    settings.json unreadable; not touched. Add the Stop hook manually.")
    sys.exit(0)
CMD = "python .claude/hooks/worklog_reminder.py"
stop = cfg.setdefault("hooks", {}).setdefault("Stop", [])
present = any(
    h.get("command") == CMD
    for grp in stop if isinstance(grp, dict)
    for h in grp.get("hooks", []) if isinstance(h, dict)
)
if present:
    print("  [skip] Stop hook already in settings.json")
else:
    stop.append({"matcher": "", "hooks": [{"type": "command", "command": CMD}]})
    json.dump(cfg, open(p, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
    print("  [ok]   merged Stop hook into existing settings.json")
__PYMERGE__
    then :; else
      echo "  [!]    settings merge failed; add this Stop hook manually:"
      echo '         {"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"python .claude/hooks/worklog_reminder.py"}]}]}}'
    fi
  else
    echo "  [!]    settings.json exists but no runnable python found; add this Stop hook manually:"
    echo '         {"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"python .claude/hooks/worklog_reminder.py"}]}]}}'
  fi
else
  cat > "$SETTINGS" <<'__SETTINGS__'
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "python .claude/hooks/worklog_reminder.py" }
        ]
      }
    ]
  }
}
__SETTINGS__
  echo "  [ok]   created $SETTINGS"
fi

echo ""
echo "Done. Keep coding - the agent now maintains WORKLOG.md, and blockers only you"
echo "can decide surface in the 'Awaiting your decision' section at its top."
echo "Tip: commit WORKLOG.md once (git add WORKLOG.md && commit) so the hook can tell"
echo "     when a turn changed code without updating the ledger."
