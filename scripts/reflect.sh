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

# Load API key: env → .env → ~/.hermes/config.yaml (try multiple providers)
if [[ -z "${LLM_API_KEY:-}" ]]; then
    if [[ -f "$COMPOUND_ROOT/.env" ]]; then
        source "$COMPOUND_ROOT/.env"
    fi
fi

if [[ -z "${LLM_API_KEY:-}" ]]; then
    # Parse from Hermes config.yaml — try providers in priority order
    HERMES_CONFIG="${HERMES_CONFIG:-$HOME/.hermes/config.yaml}"
    if [[ -f "$HERMES_CONFIG" ]] && command -v python3 &>/dev/null; then
        # Try xiaomi-sk (non-token-plan, works reliably) → xiaomi → opencode-go → deepseek
        for provider in xiaomi-sk xiaomi opencode-go deepseek; do
            LLM_API_KEY=$(python3 -c "
import yaml
try:
    with open('$HERMES_CONFIG') as f:
        cfg = yaml.safe_load(f)
    key = cfg.get('providers',{}).get('$provider',{}).get('api_key','')
    if key: print(key)
except: pass
" 2>/dev/null)
            if [[ -n "$LLM_API_KEY" ]]; then
                case "$provider" in
                    xiaomi-sk)
                        LLM_ENDPOINT="https://api.xiaomimimo.com/v1"
                        LLM_MODEL="mimo-v2.5"
                        ;;
                    xiaomi)
                        LLM_ENDPOINT="https://token-plan-cn.xiaomimimo.com/v1"
                        LLM_MODEL="mimo-v2.5"
                        ;;
                    opencode-go)
                        LLM_ENDPOINT="https://opencode.ai/zen/go/v1"
                        LLM_MODEL="deepseek-v4-pro"
                        ;;
                    deepseek)
                        LLM_ENDPOINT="https://api.deepseek.com/v1"
                        LLM_MODEL="deepseek-v4-flash"
                        ;;
                esac
                log_info "Using LLM provider: $provider" >&2
                break
            fi
        done
    fi
fi

if [[ -z "${LLM_API_KEY:-}" ]]; then
    log_error "No LLM API key found (export LLM_API_KEY, add to .env, or configure in ~/.hermes/config.yaml)"
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

# Export prompt for Python LLM caller
export COMPOUND_PROMPT="$PROMPT"
export LLM_ENDPOINT LLM_MODEL LLM_API_KEY

# Call LLM (via Python to avoid bash quoting issues)
RESPONSE=$(python3 << 'PYEOF'
import yaml, json, urllib.request, sys, os

config_path = os.path.expanduser('~/.hermes/config.yaml')
endpoint = os.environ.get('LLM_ENDPOINT', '')
model = os.environ.get('LLM_MODEL', '')
api_key = os.environ.get('LLM_API_KEY', '')

# If no env vars, parse from config
if not api_key and os.path.exists(config_path):
    with open(config_path) as f:
        cfg = yaml.safe_load(f)
    for provider in ['xiaomi', 'opencode-go', 'deepseek']:
        p = cfg.get('providers', {}).get(provider, {})
        if p.get('api_key'):
            api_key = p['api_key']
            endpoint = endpoint or p.get('base_url', '')
            model = model or p.get('default_model', '')
            break

if not api_key:
    print(json.dumps({'error': {'message': 'No API key found'}}))
    sys.exit(0)

prompt = os.environ.get('COMPOUND_PROMPT', '')
data = json.dumps({
    'model': model,
    'messages': [{'role': 'user', 'content': prompt}],
    'max_tokens': 2000,
    'temperature': 0.3
}).encode()

try:
    req = urllib.request.Request(
        f'{endpoint}/chat/completions',
        data=data,
        headers={
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {api_key}'
        }
    )
    resp = urllib.request.urlopen(req, timeout=30)
    print(resp.read().decode())
except Exception as e:
    print(json.dumps({'error': {'message': str(e)}}))
PYEOF
)

# Extract content
CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [[ -z "$CONTENT" ]]; then
    log_error "LLM call failed: $(echo "$RESPONSE" | jq -r '.error.message // "unknown error"')"
    exit 1
fi

# Parse JSON (handle markdown code blocks)
CONTENT=$(echo "$CONTENT" | sed 's/^```json//;s/^```//;s/```$//')

echo "$CONTENT"
