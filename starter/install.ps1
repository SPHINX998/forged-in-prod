<#
  forged-in-prod starter — one-shot installer (Windows PowerShell).
    Installs minimal WORKLOG automation + pending-decision surfacing into a project.
    Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 [-Target <dir>]
            (default target: current directory)

  Idempotent and fail-safe: never overwrites an existing CLAUDE.md, WORKLOG.md, or
  settings.json; re-running only fills in what's missing. Files are written as
  UTF-8 without BOM. Uninstall = delete the marked block in CLAUDE.md, the
  .claude/hooks file, and the Stop hook line in settings.json.
#>
param([string]$Target = ".")
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Target)) { Write-Error "target dir not found: $Target"; exit 1 }
Set-Location $Target
$Target = (Get-Location).Path
Write-Host "forged-in-prod starter -> $Target"

$utf8 = New-Object System.Text.UTF8Encoding $false
function WriteFile($rel, $content) {
  $p = Join-Path $Target $rel
  [System.IO.File]::WriteAllText($p, $content, $utf8)
}

# ---- 1) CLAUDE.md rules (in the agent's context every turn: the part that works) ----
$mark = "<!-- forged-in-prod:rules -->"
$claudeRules = @'
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
'@
$claudePath = Join-Path $Target "CLAUDE.md"
if ((Test-Path $claudePath) -and (Select-String -Path $claudePath -SimpleMatch $mark -Quiet)) {
  Write-Host "  [skip] CLAUDE.md already has the rules"
} else {
  $prefix = ""
  if (Test-Path $claudePath) { $prefix = [System.IO.File]::ReadAllText($claudePath) + "`n" }
  [System.IO.File]::WriteAllText($claudePath, $prefix + $claudeRules + "`n", $utf8)
  Write-Host "  [ok]   appended rules to CLAUDE.md"
}

# ---- 2) WORKLOG.md skeleton (only if absent) ----
$worklogPath = Join-Path $Target "WORKLOG.md"
if (Test-Path $worklogPath) {
  Write-Host "  [skip] WORKLOG.md exists (left untouched)"
} else {
  $worklog = @'
# WORKLOG

> Newest entry on top. See CLAUDE.md for the ledger rules.

## ⏳ Awaiting your decision (ball in your court)
> When a blocker needs a decision only you can make, an entry lands here and stays
> pinned above the log stream. Empty = nothing is waiting on you.

<!-- format: - [ ] [YYYY-MM-DD] what's blocked — the one-sentence decision — where the evidence is -->

---

<!-- log entries below, newest first -->
'@
  [System.IO.File]::WriteAllText($worklogPath, $worklog, $utf8)
  Write-Host "  [ok]   created WORKLOG.md"
}

# ---- 3) the backstop hook (fail-open, zero deps, no dead-loop) ----
$hookDir = Join-Path $Target ".claude\hooks"
New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
$hook = @'
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
'@
[System.IO.File]::WriteAllText((Join-Path $hookDir "worklog_reminder.py"), $hook, $utf8)
Write-Host "  [ok]   installed .claude\hooks\worklog_reminder.py"

# ---- 4) settings.json (create fresh, or merge the Stop hook into an existing one) ----
$claudeDir = Join-Path $Target ".claude"
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
$settingsPath = Join-Path $claudeDir "settings.json"
if (Test-Path $settingsPath) {
  # Pick a python that actually RUNS. On Windows, `python3` is often the Microsoft
  # Store app-execution-alias stub (not a working python), so we test it and skip.
  $py = $null
  foreach ($c in @("python", "python3", "py")) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) {
      & $cmd.Source -c "import sys" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { $py = $cmd.Source; break }
    }
  }
  if ($py) {
    $merge = @'
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
'@
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, $merge, $utf8)
    & $py $tmp $settingsPath
    Remove-Item $tmp -Force
  } else {
    Write-Host "  [!]    settings.json exists but python not found; add this Stop hook manually:"
    Write-Host '         {"hooks":{"Stop":[{"matcher":"","hooks":[{"type":"command","command":"python .claude/hooks/worklog_reminder.py"}]}]}}'
  }
} else {
  $settings = @'
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
'@
  [System.IO.File]::WriteAllText($settingsPath, $settings, $utf8)
  Write-Host "  [ok]   created .claude\settings.json"
}

Write-Host ""
Write-Host "Done. Keep coding - the agent now maintains WORKLOG.md, and blockers only you"
Write-Host "can decide surface in the 'Awaiting your decision' section at its top."
Write-Host "Tip: commit WORKLOG.md once (git add WORKLOG.md; git commit) so the hook can tell"
Write-Host "     when a turn changed code without updating the ledger."
