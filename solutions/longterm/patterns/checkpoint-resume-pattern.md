---
id: checkpoint-resume-pattern
title: "断点续传模式 (Checkpoint/Resume Pattern)"
created: 2026-06-17
severity: "medium"
type: pattern
category: software-development
tags: checkpoint, resume, fault-tolerance, batch-processing
maturity: proven
---

# 断点续传模式 (Checkpoint/Resume Pattern)

## 问题

长时间运行的批量任务（评估、重嵌入、数据标注等）容易因网络/进程中断而丢失进度，从头开始代价高昂。

## 解决方案

**核心思想**：每完成一个单元，立即持久化结果到 checkpoint 文件，中断后从断点继续。

### 实现模板

```python
# 1. Checkpoint 文件结构
{
    "meta": { "config": "..." },        # 运行参数
    "completed_cases": {                  # 已完成的 case
        "case_001": { "result": "..." },
        "case_002": { "result": "..." }
    }
}

# 2. CLI 参数
--resume           # 从 checkpoint 加载，跳过已完成
--checkpoint-path  # checkpoint 文件路径
--no-checkpoint    # 不保存 checkpoint（快速测试用）

# 3. 核心逻辑
def run_with_checkpoint(cases, checkpoint_path, resume=False):
    # 加载 checkpoint
    completed = load_checkpoint(checkpoint_path) if resume else {}
    
    # 过滤已完成
    remaining = [c for c in cases if c not in completed]
    
    # 逐个处理
    for case in remaining:
        result = process(case)
        append_checkpoint(checkpoint_path, case, result)
    
    # 合并结果
    all_results = merge(completed, new_results)
    
    # 成功后删除 checkpoint
    delete_checkpoint(checkpoint_path)
    
    return all_results
```

### 关键设计决策

| 决策 | 推荐 | 原因 |
|------|------|------|
| Checkpoint 格式 | JSON | 可读、可调试、Python 原生支持 |
| 写入时机 | 每个 case 完成后 | 最小化丢失风险 |
| 成功后处理 | 删除 checkpoint | 避免下次误用旧 checkpoint |
| 损坏处理 | 警告 + 重新开始 | 从部分损坏恢复比从头开始更危险 |

### 适用场景

| 场景 | 典型耗时 | 收益 |
|------|----------|------|
| A/B 对比 (400 tickets) | 10-30 min | ✅ 高 |
| LLM-as-judge 评估 | 5-15 min | ✅ 高 |
| 批量重嵌入 | 2-10 min | ✅ 中 |
| 数据标注 | 10-60 min | ✅ 高 |
| 单次检索测试 | <1 min | ❌ 低 |

### 反模式

- ❌ 全部完成后一次性写入（中断=全丢）
- ❌ 频繁写入（每行/每条记录，IO 开销大）
- ❌ checkpoint 文件太大（>100MB，加载慢）
- ❌ 不处理损坏的 checkpoint

## 实现案例

### TicketPilot 项目

1. **run_sag_comparison.py** — A/B 对比，每 case 保存，支持 `--resume`
2. **resumable_seed.py** — 数据库 seeding，用 `ON CONFLICT DO NOTHING` + 进度追踪

## 相关

- 错误学习: `error-learning` skill
- TDD: 每个 checkpoint 功能都要有测试
