# Starter — 最小 WORKLOG 自动化 / Minimal WORKLOG automation

[中文](#中文) · [English](#english)

> 这不是「自动生成」，也没有全局开关。让 AI 持续维护工作日志靠的是三件事：
> **① 规则常驻**（写进 AI 每轮必读的 CLAUDE.md）+ **② hook 兜底** + **③ 恢复时先读回**。
> 单发提示词必然失败，因为它不常驻——AI 下一轮就忘。
>
> This is **not** "auto-generation" and there is no global switch. Getting an AI
> to keep a worklog rests on three things: **① a resident rule** (in the CLAUDE.md
> it reads every turn) + **② a backstop hook** + **③ read-back on recovery**.
> A one-off prompt always fails — it isn't resident, so the next turn forgets it.

---

## 中文

### 装法（3 步，约 2 分钟）

1. **规则常驻（最重要，80% 的效果在这）**
   打开 [`CLAUDE.snippet.md`](CLAUDE.snippet.md)，把里面的中文块粘进你项目根目录的
   `CLAUDE.md`（没有就新建）。想对所有项目全局生效，就粘进 `~/.claude/CLAUDE.md`。

2. **hook 兜底（可选，防 AI 偷懒）**
   把本目录的 `.claude/` 整个拷到你项目根目录（或合并进已有的 `.claude/`）。它包含：
   - `.claude/settings.json` — 注册一个 `Stop` hook
   - `.claude/hooks/worklog_reminder.py` — 检测「这轮动了代码但没更新 WORKLOG」时提醒一次

3. **建账本**
   项目根 `touch WORKLOG.md`（空文件即可，AI 会按规则往里写）。

### 为什么这样就行

`CLAUDE.md` 每轮对话都注入上下文，所以规则每次都「提醒」AI 一遍——这才是所谓的「全局」。
hook 只是兜底：AI 收尾时若发现代码有改动但 WORKLOG 没同步更新，就挡一次并要求补记。
hook **fail-open**：非 git 仓、没装 python、任何异常都直接放行，绝不会卡住你的会话。

### 坑

- hook 命令默认用 `python`。Windows 上若 `python` 不在 PATH，改 `.claude/settings.json`
  里的命令为 `py` 或 `python3`。
- hook 只在 git 仓库里生效（靠 `git status` 判断改动）。
- 想要更重的版本（多 agent 并行、跨会话恢复门禁）不在本 starter 内——那属于完整方法论，
  见仓库根 [README](../README.md) 的模式一到模式五。**先从这个最小版跑起来。**

---

## English

### Install (3 steps, ~2 min)

1. **Resident rule (this is 80% of the effect)**
   Open [`CLAUDE.snippet.md`](CLAUDE.snippet.md) and paste the English block into
   your project's root `CLAUDE.md` (create it if absent). For every project on your
   machine, paste it into `~/.claude/CLAUDE.md` instead.

2. **Backstop hook (optional, for the turns the model forgets)**
   Copy this folder's `.claude/` into your project root (or merge into an existing
   `.claude/`). It contains:
   - `.claude/settings.json` — registers a `Stop` hook
   - `.claude/hooks/worklog_reminder.py` — reminds once when a turn changed code
     but left WORKLOG.md untouched

3. **Create the ledger**
   `touch WORKLOG.md` at the repo root (an empty file is fine; the agent fills it).

### Why this works

`CLAUDE.md` is injected into context every turn, so the rule re-primes the agent
each time — that is what "global" actually means here. The hook is only a backstop:
at turn-end, if code changed but WORKLOG didn't, it blocks once and asks for an
entry. The hook is **fail-open** — no git, no python, or any error just lets the
turn end. It can never wedge your session.

### Gotchas

- The hook command uses `python`. On Windows, if `python` isn't on PATH, change it
  to `py` or `python3` in `.claude/settings.json`.
- The hook only acts inside a git repo (it reads `git status` to detect changes).
- The heavier machinery (parallel agents, cross-session recovery gates) is **not**
  in this starter — that's the full methodology; see Patterns 1–5 in the root
  [README](../README.en.md). Start with this minimal version first.
