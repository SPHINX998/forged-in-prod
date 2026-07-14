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

<!-- ============ 中文 ============ -->

## 任务账本（WORKLOG.md）

仓库根目录只保留一份 `WORKLOG.md` 作为唯一任务账本。

- **动代码 → 追加一条。** 不动代码不记。
- 每条只记两件事：**总目标**（这轮要交付什么）和**干到哪了**——含**验证证据**
  （跑了什么命令、看到什么输出）和**下一步**。
- 上下文压缩或新会话后，**先读最新的 WORKLOG 条目**再接着干，不重查里面已验证的事实。
- 禁止第二份进度文档。要么一份账本，要么没有。

合格标准：一个零上下文的 agent 只凭最新条目就能接着干活；没有证据行的「已完成」不算完成。
