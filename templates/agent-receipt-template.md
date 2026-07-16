# Agent 短回执模板

用于真正需要多分支并行的长任务。详细调查过程留在临时 runtime artifact；主线程先消费短回执，命中触发条件才打开正文。

```yaml
verdict: confirmed | rejected | blocked
relevant_to: <当前阶段哪个验收条件或决策门>
baseline_identity: <commit / revision / snapshot / request / deployment 等可复现身份>
evidence: <断言范围、检查方法、覆盖分母、排除项、穷尽或抽样、可复核入口与结果状态>
artifact_path: <临时 runtime artifact 路径>
invalidate_if: <哪些变化会使证据失效>
needs_main_now: yes | no
```

## 写回执

- `evidence` 必须写清：检查了多少、已知总量多少、排除了什么、是穷尽还是抽样。
- 给出可复核执行入口或请求定位、作用域、结果状态和 `baseline_identity`；适用时附精确命令与退出码。
- 正向存在性断言可给 `file:line` 等定点指针；「不存在 / 没遗漏 / 全部覆盖」必须证明搜索范围和分母。
- 详细结果和长日志原样写入项目约定的临时 runtime artifact；本模板不为压缩回执额外脱敏或删改证据，项目自身禁止采集的内容仍不得采集。

## 消费回执

- 主线程默认不读 artifact 正文；只有影响当前决策、高风险、证据冲突、抽查失败或短回执不足时才打开。
- 复用前，用当前 identity 评估 `invalidate_if`；无法评估就视为失效并重验。
- `accepted` 只表示在回执声明的覆盖范围内接受，不能把抽样升级成穷尽结论。
- 失败或超时使用 `verdict: blocked`，并明确当前决策门是继续阻塞，还是带着已声明的覆盖缺口继续。
- runtime artifact 是易失证据缓存，不是任务账本或长期事实 owner；需要长期保留的结论提升到唯一 owner 文档。

## 验证边界

- 每个分支跑目标检查并保存可复核证据。
- 合并后必须真实驱动组合目标路径做一次权威验证；多份分支绿灯不能替代整合验收。
- 协调 agent、怀疑者 agent、分层汇总只在分支多、同质、冲突或高风险时按需使用，不是默认步骤。
