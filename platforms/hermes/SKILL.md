---
name: compound-system
description: "Post-task reflection and knowledge management system. Auto-extracts errors and solutions, builds searchable knowledge base."
category: productivity
---

# Compound Engineering System

> **自动触发规则**: 任务完成后自动调用此 skill 进行反思。错误/复杂任务必反思，简单配置可跳过。

## Quick Start

After finishing any task, run the reflection pipeline:

```bash
# Full reflection (auto-detects level)
~/.hermes/skills/compound-system/scripts/compound.sh --task "description" --status "success|partial|failed"

# Manual search before starting a new task
~/.hermes/skills/compound-system/scripts/search.sh "error keyword"

# Write a solution manually
~/.hermes/skills/compound-system/scripts/write-solution.sh

# Lifecycle maintenance
~/.hermes/skills/compound-system/scripts/refresh.sh
```

## Workflow

### After Every Task

1. **Rule Gate** (zero cost) — checks if reflection is needed
   - Skip: simple config changes, documentation only, trivial fixes
   - Trigger: errors, retries, complexity, partial success

2. **Quick Reflect** (~$0.0002) — flash model extracts:
   - What happened
   - Root cause
   - Solution (if any)
   - Tags for retrieval

3. **Deep Reflect** (~$0.03) — pro model for:
   - Cross-domain patterns
   - Architecture decisions
   - Reusable insights

### Before Starting a New Task

1. **Search** the solutions directory:
   ```bash
   scripts/search.sh "error description"
   ```

2. **Check CONCEPTS.md** for vocabulary:
   - Read `solutions/CONCEPTS.md`
   - Use domain-specific terms in searches

3. **Use search tips**:
   - Try: `[tag] error_keyword` (e.g., `[auth] api key`)
   - Try: `module_name error` (e.g., `lark-cli timeout`)
   - Try: `error_code` (e.g., `401`, `500`)
   - Check frontmatter first, then content

## Directory Structure

```
solutions/
├── CONCEPTS.md          # Auto-maintained vocabulary
├── bugs/                # Error patterns & fixes
│   ├── 2026-06-14-api-401.md
│   └── 2026-06-14-yaml-type-error.md
├── knowledge/           # Architecture & best practices
│   └── 2026-06-14-storage-schema.md
└── patterns/            # Reusable solutions
    └── 2026-06-14-retry-pattern.md
```

## File Format (YAML Frontmatter)

```yaml
---
title: "Error Description"
module: "tool/project name"
tags: [error_type, tool, context]
problem_type: "bug|knowledge|pattern"
severity: "low|medium|high|critical"
root_cause: "Why it happened"
solution: "How to fix it"
created: "2026-06-14"
last_updated: "2026-06-14"
occurrence_count: 1
---
```

## Cost Optimization

| Level | Trigger | Cost | When |
|-------|---------|------|------|
| Skip | Simple tasks | $0 | Config changes, docs |
| Quick | Errors, complexity | ~$0.0002 | Most situations |
| Deep | Critical, cross-domain | ~$0.03 | Architecture decisions |

**Rule Gate**: Zero-cost filtering saves 40-50% of LLM calls.

## Tags Reference

| Category | Tags |
|----------|------|
| API/Auth | `auth`, `401`, `expired-key`, `rate-limit` |
| Config | `yaml`, `env`, `port-conflict`, `type-error` |
| Network | `ssh`, `vpn`, `dns`, `timeout` |
| Tool | `mcp`, `pydantic`, `import-error` |
| Code | `type-mismatch`, `null-ref`, `logic-error` |

## Maintenance

Run `scripts/refresh.sh` periodically:
- Finds stale docs (90+ days)
- Archives low-value stale docs
- Updates CONCEPTS.md
- Reports duplicates
