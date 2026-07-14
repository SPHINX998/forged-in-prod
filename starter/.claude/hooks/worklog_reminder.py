#!/usr/bin/env python3
"""
WORKLOG reminder — a Claude Code `Stop` hook.

Fires when the agent tries to end its turn. If the git working tree has code
changes but WORKLOG.md was NOT touched this turn, it blocks the stop once and
tells the agent to record an entry. Otherwise it stays silent.

Design rules (this is the whole point of Pattern 6 — anti-over-engineering):
  - FAIL-OPEN: any error, missing git, missing python feature -> exit 0, never
    trap the user. A reminder hook must never be able to wedge a session.
  - NO DEAD-LOOP: honours `stop_hook_active` so it reminds at most once.
  - ZERO DEPENDENCIES: standard library only.

The heavy lifting is still done by the CLAUDE.md rule (which is in context every
turn). This hook is only the backstop for the turns the model forgets.
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
    # Read the hook payload from stdin (Claude Code sends JSON).
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # fail-open: can't parse -> let the turn end

    # Already reminded once this turn -> don't loop.
    if payload.get("stop_hook_active"):
        return 0

    try:
        root = git(None, "rev-parse", "--show-toplevel").strip()
        if not root:
            return 0  # not a git repo -> nothing to compare against
        root = Path(root)

        # `git status --porcelain` -> "XY path" per changed file.
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
