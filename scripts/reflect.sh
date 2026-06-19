#!/usr/bin/env bash
# Level 1: Quick Reflect — generate structured summary
# Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>
#
# Requires: LLM_API_KEY env var (supports OpenAI-compatible APIs)
# Optional: LLM_ENDPOINT (default: api.deepseek.com), LLM_MODEL (default: deepseek-chat)
#
# Configuration priority:
#   1. Environment variables (LLM_API_KEY, LLM_ENDPOINT, LLM_MODEL)
#   2. .env file in COMPOUND_ROOT
#   3. Platform-specific config (~/.hermes/config.yaml, ~/.config/compound/config.yaml)
#   4. Default values

COMPOUND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$COMPOUND_ROOT/scripts/utils.sh"

TASK_DESC="${1:?Usage: reflect.sh <task_description> <outcome> <severity> <error_messages>}"
OUTCOME="${2:-success}"
SEVERITY="${3:-none}"
ERROR_MSG="${4:-}"

# Default LLM config (can be overridden by env or .env)
DEFAULT_LLM_ENDPOINT="https://api.deepseek.com/v1"
DEFAULT_LLM_MODEL="deepseek-chat"

# Load configuration: env → .env → platform config
load_config() {
    # 1. Check environment variables first
    if [[ -n "${LLM_API_KEY:-}" ]]; then
        return
    fi

    # 2. Load from .env file
    if [[ -f "$COMPOUND_ROOT/.env" ]]; then
        source "$COMPOUND_ROOT/.env"
    fi

    # 3. Try platform-specific configs
    if [[ -z "${LLM_API_KEY:-}" ]]; then
        # Detect Python command
        local python_cmd="python3"
        if ! command -v python3 &>/dev/null; then
            python_cmd="python"
        fi

        # Try multiple config locations
        local config_files=(
            "$HOME/.hermes/config.yaml"
            "$HOME/.config/compound/config.yaml"
            "$HOME/.config/compound-system/config.yaml"
        )

        for config_file in "${config_files[@]}"; do
            if [[ -f "$config_file" ]] && command -v $python_cmd &>/dev/null; then
                # Try providers in priority order
                for provider in deepseek openai xiaomi xiaomi-sk anthropic; do
                    LLM_API_KEY=$($python_cmd -c "
import yaml, json
try:
    with open('$config_file') as f:
        cfg = yaml.safe_load(f)
    providers = cfg.get('providers', {})
    p = providers.get('$provider', {})
    key = p.get('api_key', '')
    if key: print(key)
except: pass
" 2>/dev/null)
                    if [[ -n "$LLM_API_KEY" ]]; then
                        # Set endpoint and model based on provider
                        case "$provider" in
                            deepseek)
                                LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.deepseek.com/v1}"
                                LLM_MODEL="${LLM_MODEL:-deepseek-chat}"
                                ;;
                            openai)
                                LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.openai.com/v1}"
                                LLM_MODEL="${LLM_MODEL:-gpt-4o-mini}"
                                ;;
                            xiaomi)
                                LLM_ENDPOINT="${LLM_ENDPOINT:-https://token-plan-cn.xiaomimimo.com/v1}"
                                LLM_MODEL="${LLM_MODEL:-mimo-v2.5}"
                                ;;
                            xiaomi-sk)
                                LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.xiaomimimo.com/v1}"
                                LLM_MODEL="${LLM_MODEL:-mimo-v2.5}"
                                ;;
                            anthropic)
                                LLM_ENDPOINT="${LLM_ENDPOINT:-https://api.anthropic.com/v1}"
                                LLM_MODEL="${LLM_MODEL:-claude-3-haiku-20240307}"
                                ;;
                        esac
                        log_info "Using LLM provider: $provider (from $config_file)" >&2
                        break
                    fi
                done
            fi
        done
    fi
}

# Load configuration
load_config

# Set defaults if not configured
LLM_ENDPOINT="${LLM_ENDPOINT:-$DEFAULT_LLM_ENDPOINT}"
LLM_MODEL="${LLM_MODEL:-$DEFAULT_LLM_MODEL}"

# Validate API key
if [[ -z "${LLM_API_KEY:-}" ]]; then
    log_error "No LLM API key found!"
    echo ""
    echo "Configuration options:"
    echo "  1. Run setup wizard: bash scripts/setup.sh"
    echo "  2. Export environment variable: export LLM_API_KEY=your-key"
    echo "  3. Create .env file in $COMPOUND_ROOT"
    echo ""
    echo "Supported providers: deepseek, openai, xiaomi, xiaomi-sk, anthropic, custom"
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
# Detect Python command (Windows uses 'python', Unix uses 'python3')
PYTHON_CMD="python3"
if ! command -v python3 &>/dev/null; then
    PYTHON_CMD="python"
fi

# Write Python script to temp file
TEMP_SCRIPT=$(mktemp /tmp/reflect_XXXXXX.py)
cat > "$TEMP_SCRIPT" << 'PYEOF'
import yaml, json, urllib.request, sys, os, base64

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
}).encode('utf-8')

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
    response_bytes = resp.read()
    # Encode to base64 to avoid shell encoding issues
    print(base64.b64encode(response_bytes).decode('ascii'))
except Exception as e:
    error_json = json.dumps({'error': {'message': str(e)}})
    print(base64.b64encode(error_json.encode('utf-8')).decode('ascii'))
PYEOF

RESPONSE_B64=$($PYTHON_CMD "$TEMP_SCRIPT")
rm -f "$TEMP_SCRIPT"

# Decode base64 response
RESPONSE=$(echo "$RESPONSE_B64" | base64 -d 2>/dev/null || echo "$RESPONSE_B64")

# Extract content using Python (jq not available on Windows)
# Write response to temp file to avoid shell escaping issues
# Use TEMP on Windows, TMPDIR or /tmp on Unix
if [[ -n "${TEMP:-}" ]]; then
    TEMP_RESPONSE=$(mktemp "$TEMP/response_XXXXXX.json")
elif [[ -n "${TMPDIR:-}" ]]; then
    TEMP_RESPONSE=$(mktemp "$TMPDIR/response_XXXXXX.json")
else
    TEMP_RESPONSE=$(mktemp /tmp/response_XXXXXX.json)
fi
echo "$RESPONSE" > "$TEMP_RESPONSE"

# Use Python to parse JSON from file (avoids shell escaping issues)
# Set PYTHONIOENCODING to ensure proper UTF-8 output
export PYTHONIOENCODING=utf-8
CONTENT=$($PYTHON_CMD << PYEOF
import json, sys, os
temp_file = r'$TEMP_RESPONSE'
try:
    with open(temp_file, 'r', encoding='utf-8', errors='replace') as f:
        data = json.load(f)
    content = data.get('choices', [{}])[0].get('message', {}).get('content', '')
    error = data.get('error', {}).get('message', '')
    if content:
        # Ensure proper encoding
        sys.stdout.reconfigure(encoding='utf-8')
        print(content)
    elif error:
        print('ERROR: ' + error, file=sys.stderr)
except Exception as e:
    print('ERROR: ' + str(e), file=sys.stderr)
PYEOF
)
rm -f "$TEMP_RESPONSE"

if [[ -z "$CONTENT" ]]; then
    log_error "LLM call failed"
    exit 1
fi

# Parse JSON (handle markdown code blocks)
CONTENT=$(echo "$CONTENT" | sed 's/^```json//;s/^```//;s/```$//')

echo "$CONTENT"
