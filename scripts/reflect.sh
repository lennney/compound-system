#!/usr/bin/env bash
# Level 1: Quick Reflect — generate structured summary
# Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>
#
# Requires: LLM_API_KEY env var (supports OpenAI-compatible APIs)
# Optional: LLM_ENDPOINT (default: api.deepseek.com), LLM_MODEL (default: deepseek-v4-flash)

COMPOUND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$COMPOUND_ROOT/scripts/utils.sh"

TASK_DESC="${1:?Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>}"
OUTCOME="${2:-success}"
SEVERITY="${3:-none}"
ERROR_MSG="${4:-}"

# LLM config
LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.deepseek.com/v1}"
LLM_MODEL="${LLM_MODEL:-deepseek-v4-flash}"

# Load API key from environment or .env file
if [[ -z "${LLM_API_KEY:-}" ]]; then
    if [[ -f "$COMPOUND_ROOT/.env" ]]; then
        source "$COMPOUND_ROOT/.env"
    fi
fi

if [[ -z "${LLM_API_KEY:-}" ]]; then
    log_error "LLM_API_KEY not set (export or add to .env)"
    exit 1
fi

PROMPT="你是一个错误模式提取器。分析以下任务执行记录，提取关键信息。

## 任务信息
- 描述: ${TASK_DESC}
- 结果: ${OUTCOME}
- 严重程度: ${SEVERITY}

## 错误信息
${ERROR_MSG:-无}

## 输出要求（JSON）
{
  \"pattern_title\": \"简短标题（<20字）\",
  \"track\": \"bug|knowledge\",
  \"error_type\": \"API错误|配置错误|网络错误|工具错误|代码质量|环境问题|无错误\",
  \"root_cause\": \"根本原因（一句话）\",
  \"solution_summary\": \"解决方案摘要（3步以内）\",
  \"tags\": [\"精确标签1\", \"精确标签2\", \"精确标签3\"],
  \"reusable_pattern\": true,
  \"confidence\": 0.8
}

只输出 JSON，不要其他文字。"

# Call LLM
RESPONSE=$(curl -s "${LLM_ENDPOINT}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${LLM_API_KEY}" \
    -d "$(jq -n \
        --arg model "$LLM_MODEL" \
        --arg prompt "$PROMPT" \
        '{
            model: $model,
            messages: [{role: "user", content: $prompt}],
            max_tokens: 500,
            temperature: 0.3
        }')")

# Extract content
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -z "$CONTENT" ]]; then
    log_error "LLM call failed: $(echo "$RESPONSE" | jq -r '.error.message // "unknown error"')"
    exit 1
fi

# Parse JSON (handle markdown code blocks)
CONTENT=$(echo "$CONTENT" | sed 's/^```json//;s/^```//;s/```$//')

echo "$CONTENT"
