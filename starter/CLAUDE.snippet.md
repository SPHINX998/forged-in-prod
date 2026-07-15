<!--
Paste ONE of the blocks below into your project's CLAUDE.md (or AGENTS.md, or
~/.claude/CLAUDE.md for every project). This is the part that actually works:
it is in the agent's context every single turn, so the rule never gets forgotten.
The hook is only a backstop.
-->

<!-- ============ ENGLISH ============ -->

## Task ledger (WORKLOG.md)

Keep exactly one `WORKLOG.md` at the repo root as the single task ledger.

- **Touch code → append an entry.** No code touched, no entry.
- Each entry records only two things: **the goal** (what this work must deliver)
  and **where things stand** — including **verification evidence** (what command
  ran, what output appeared) and **the next step**.
- After a context compaction or a new session, **read the latest WORKLOG entry
  first** and continue from it. Do not re-investigate facts already verified there.
- Never create a second progress doc. One ledger, or none.

Quality bar: a fresh agent with zero context must be able to resume the work from
the latest entry alone. "Done" with no evidence line is not done.

## Surfacing decisions only the user can make

When you hit a blocker whose root cause is a decision only the user can make (not
something you can resolve yourself), do two things: record it where it belongs, AND
append one line to the fixed "⏳ Awaiting your decision" section at the very top of
`WORKLOG.md` (between the header note and the first log entry) — date, what's
blocked, the one-sentence decision, and where the evidence is. That section is
pinned above the log stream so it never scrolls away. Strike the line once the
decision lands. Only user-decidable blockers go here; anything you can resolve
yourself does not.

<!-- ============ 中文 ============ -->

## 任务账本（WORKLOG.md）

仓库根目录只保留一份 `WORKLOG.md` 作为唯一任务账本。

- **动代码 → 追加一条。** 不动代码不记。
- 每条只记两件事：**总目标**（这轮要交付什么）和**干到哪了**——含**验证证据**
  （跑了什么命令、看到什么输出）和**下一步**。
- 上下文压缩或新会话后，**先读最新的 WORKLOG 条目**再接着干，不重查里面已验证的事实。
- 禁止第二份进度文档。要么一份账本，要么没有。

合格标准：一个零上下文的 agent 只凭最新条目就能接着干活；没有证据行的「已完成」不算完成。

## 把需要用户拍板的决定冒泡出来

遇到一个卡点、其根因是"只有用户能拍板的决定"（不是你自己能解的）时，做两件事：记录到该
记的地方，并往 `WORKLOG.md` 顶部固定的「⏳ 待你裁决」小节（头部说明与首条日志之间）追加
一行——日期、卡住了什么、一句话决策点、证据在哪。这个小节钉在日志流之上，永不下沉。用户
拍板后划掉。只有需要用户裁的卡点进这里；你自己能解的不进。
