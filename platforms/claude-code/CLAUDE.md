# Compound Engineering System — Claude Code

## Post-Task Reflection

After completing any task, run:

```bash
# Auto-reflect based on task status
~/.hermes/skills/compound-system/scripts/compound.sh --task "description" --status "success|partial|failed"
```

## Before Starting a Task

Search existing solutions:

```bash
~/.hermes/skills/compound-system/scripts/search.sh "error description"
```

## Key Files

- `solutions/bugs/` — Error patterns and fixes
- `solutions/knowledge/` — Architecture decisions
- `solutions/patterns/` — Reusable solutions
- `solutions/CONCEPTS.md` — Auto-maintained vocabulary

## When to Reflect

- Errors or failures → Always reflect
- Multiple retries → Always reflect
- Complex decisions → Always reflect
- Simple config changes → Skip
- Documentation only → Skip

## Cost Levels

| Level | Cost | Use Case |
|-------|------|----------|
| Skip | $0 | Simple tasks |
| Quick | ~$0.0002 | Most errors |
| Deep | ~$0.03 | Critical/architecture |

## Search Tips

1. Try: `[tag] keyword` (e.g., `[auth] api key`)
2. Try: `module error` (e.g., `lark-cli timeout`)
3. Check frontmatter first, then content
4. Use CONCEPTS.md for vocabulary
