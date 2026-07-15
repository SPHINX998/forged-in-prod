# Starter — 最小 WORKLOG 自动化 / Minimal WORKLOG automation

[中文](#中文) · [English](#english)

> 这不是「自动生成」，也没有全局开关。让 AI 持续维护工作日志靠三件事：
> **① 规则常驻**（写进 AI 每轮必读的 CLAUDE.md）+ **② hook 兜底** + **③ 恢复时先读回**。
> 单发提示词必然失败，因为它不常驻——AI 下一轮就忘。
>
> This is **not** "auto-generation" and there is no global switch. It rests on three
> things: **① a resident rule** (in the CLAUDE.md the agent reads every turn) +
> **② a backstop hook** + **③ read-back on recovery**. A one-off prompt always
> fails — it isn't resident, so the next turn forgets it.

---

## 中文

### 一键安装（0 成本，推荐）

在你的**项目根目录**跑一条命令。幂等（可重复跑），**绝不覆盖**你已有的 `CLAUDE.md` / `WORKLOG.md` / `settings.json`——只补缺的。

**Mac / Linux / WSL / Git-Bash：**
```sh
curl -fsSL https://raw.githubusercontent.com/SPHINX998/forged-in-prod/main/starter/install.sh | sh
```

**Windows PowerShell：**
```powershell
iwr -useb https://raw.githubusercontent.com/SPHINX998/forged-in-prod/main/starter/install.ps1 | iex
```

> 想先看一眼再跑？把脚本下载下来读完再执行——它只写 4 个文件、`git status` 只读、不碰别的。
> 已经 clone 了仓库？直接 `sh starter/install.sh` 或 `powershell -File starter\install.ps1`。

**装完它给你：**
- `CLAUDE.md` — 追加账本规则 + 待裁决冒泡规则（用标记块包裹，重复跑不重复加）
- `WORKLOG.md` — 骨架，含顶部固定的「⏳ 待你裁决」小节
- `.claude/hooks/worklog_reminder.py` — 兜底 hook（fail-open）
- `.claude/settings.json` — 注册 `Stop` hook（已有配置会**智能合并**，保留你原有的）

**最后一步：** `git add WORKLOG.md` 提交一次——hook 靠 git 判断改动，账本进了库它才能分辨「这轮改了代码却没记账本」。

### 为什么这样就行

`CLAUDE.md` 每轮对话都注入上下文，规则每次都「提醒」AI 一遍——这才是所谓的「全局」。hook 只是兜底：AI 收尾时若发现代码有改动但 WORKLOG 没同步，就挡一次要求补记。hook **fail-open**：非 git 仓、没装 python、任何异常都直接放行，绝不卡住你的会话。

### 待裁决冒泡（球在你这儿）

规则还让 AI 把「**只有你能拍板的卡点**」冒泡到 `WORKLOG.md` 顶部那个固定的「⏳ 待你裁决」小节——它钉在日志流之上，永不被新日志冲走。你瞄一眼 WORKLOG 顶部就知道有没有决定在等你，不用主动追问 AI 卡在哪。只有需要你裁的进这里；AI 自己能解的技术卡点不进。

### 手动装（不想跑脚本时）

1. 把 [`CLAUDE.snippet.md`](CLAUDE.snippet.md) 里的中文块粘进你的 `CLAUDE.md`（全局就粘 `~/.claude/CLAUDE.md`）。
2. 把本目录 `.claude/` 拷进项目根（已有 `settings.json` 就手动合并那段 `Stop` hook）。
3. 建 `WORKLOG.md`，顶部放一个「⏳ 待你裁决」小节。

### 坑

- 脚本自动挑**真能跑的** python（Windows 上会跳过微软商店的 `python3` 存根）。装好的 hook 命令用 `python`；若你的环境只有 `py`，改 `.claude/settings.json` 里那条命令。
- hook 只在 git 仓里生效（靠 `git status` 判断改动）。
- 想要更重的（多 agent 并行、跨会话恢复门禁）不在本 starter 内——那是完整方法论，见根 [README](../README.md) 的模式一到六。**先从这个最小版跑起来。**

---

## English

### One-line install (zero-cost, recommended)

Run one command in your **project root**. Idempotent (safe to re-run), and it
**never overwrites** your existing `CLAUDE.md` / `WORKLOG.md` / `settings.json` —
it only fills in what's missing.

**Mac / Linux / WSL / Git-Bash:**
```sh
curl -fsSL https://raw.githubusercontent.com/SPHINX998/forged-in-prod/main/starter/install.sh | sh
```

**Windows PowerShell:**
```powershell
iwr -useb https://raw.githubusercontent.com/SPHINX998/forged-in-prod/main/starter/install.ps1 | iex
```

> Prefer to read before you run? Download the script and read it first — it writes
> only 4 files, reads `git status`, and touches nothing else. Already cloned the
> repo? Just `sh starter/install.sh` or `powershell -File starter\install.ps1`.

**What it installs:**
- `CLAUDE.md` — appends the ledger rule + decision-surfacing rule (in a marked
  block, so re-running never duplicates it)
- `WORKLOG.md` — a skeleton with the pinned "⏳ Awaiting your decision" section
- `.claude/hooks/worklog_reminder.py` — the fail-open backstop hook
- `.claude/settings.json` — registers the `Stop` hook (an existing config is
  **merged**, your other settings are preserved)

**Last step:** `git add WORKLOG.md` and commit it once — the hook uses git to
detect changes, so the ledger must be tracked before it can tell a turn changed
code without updating it.

### Why this works

`CLAUDE.md` is injected into context every turn, so the rule re-primes the agent
each time — that is what "global" actually means here. The hook is only a backstop:
at turn-end, if code changed but WORKLOG didn't, it blocks once and asks for an
entry. It is **fail-open** — no git, no python, or any error just lets the turn
end. It can never wedge your session.

### Surfacing decisions (ball in your court)

The rule also makes the agent bubble up **blockers only you can decide** into the
fixed "⏳ Awaiting your decision" section at the top of `WORKLOG.md` — pinned above
the log stream so it never scrolls away. Glance at the top of WORKLOG and you know
whether a decision is waiting on you, without having to ask the agent what it's
stuck on. Only user-decidable blockers go here; anything the agent can resolve
itself does not.

### Manual install (if you'd rather not run a script)

1. Paste the English block from [`CLAUDE.snippet.md`](CLAUDE.snippet.md) into your
   `CLAUDE.md` (or `~/.claude/CLAUDE.md` for all projects).
2. Copy this folder's `.claude/` into your project root (merge the `Stop` hook by
   hand if you already have a `settings.json`).
3. Create `WORKLOG.md` with an "⏳ Awaiting your decision" section at the top.

### Gotchas

- The script picks a python that **actually runs** (it skips the Microsoft Store
  `python3` alias stub on Windows). The installed hook command uses `python`; if
  your environment only has `py`, change that command in `.claude/settings.json`.
- The hook only acts inside a git repo (it reads `git status`).
- The heavier machinery (parallel agents, cross-session recovery gates) is **not**
  in this starter — that's the full methodology; see Patterns 1–6 in the root
  [README](../README.en.md). Start with this minimal version first.
