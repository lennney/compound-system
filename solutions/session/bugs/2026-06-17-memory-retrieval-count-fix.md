---
id: memory-system-bugfix-2026-06-17
title: "记忆系统 Bug 修复：retrieval_count 不更新"
created: 2026-06-17
severity: "medium"
type: bug
category: memory-system
tags: holographic, retrieval_count, fact-store, bugfix
maturity: proven
---

# 记忆系统 Bug 修复：retrieval_count 不更新

## 问题

`fact_store` 的 23 条 facts 全部 `retrieval_count=0`，即使被搜索过也不更新。

## 根因

`FactRetriever.search()` 调用 `_fts_candidates()` 获取 FTS5 结果，但 `_fts_candidates()` **不更新 retrieval_count**。只有 `store.search_facts()` 才会更新，但 retriever 没调用它。

**代码路径：**
```
fact_store(action='search')
  → holographic.py._handle_fact_store()
    → retriever.search()
      → _fts_candidates()  ← 这里不更新 retrieval_count
      → return results  ← retrieval_count 仍然是 0
```

## 修复

在 `retrieval.py` 中：

1. 新增 `_increment_retrieval_counts()` 公共方法
2. 在 `search()`、`probe()`、`related()`、`reason()`、`_score_facts_by_vector()`、`_fts_candidates()` 返回结果前调用

```python
def _increment_retrieval_counts(self, fact_ids: list[int]) -> None:
    """Increment retrieval_count for retrieved facts."""
    if not fact_ids:
        return
    conn = self.store._conn
    placeholders = ",".join("?" * len(fact_ids))
    conn.execute(
        f"UPDATE facts SET retrieval_count = retrieval_count + 1 WHERE fact_id IN ({placeholders})",
        fact_ids,
    )
    conn.commit()
```

## 影响

- 修复后，每次 `fact_store(search/probe/related/reason)` 都会更新 `retrieval_count`
- `retrieval_count` 可用于排序高频使用的 facts
- 不影响现有功能，只是补全了计数逻辑

## AgentMemory MCP Sessions 为空

**状态：** 设计如此，非 bug

AgentMemory MCP 是独立服务，不跟踪 session。`memory_save` 写入 observations 但不创建 session 记录。session tracking 需要额外配置（如 Honcho 或自定义 session manager）。
