#!/usr/bin/env bash
CIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CIB_ROOT/config.env"

[[ -n "${PRESET:-}" ]] || { echo "common.sh: PRESET is not set in config.env" >&2; exit 1; }
[[ -f "$CIB_ROOT/model_presets/$PRESET.env" ]] || { echo "common.sh: no preset file for '$PRESET' (expected model_presets/$PRESET.env)" >&2; exit 1; }

source "$CIB_ROOT/model_presets/$PRESET.env"

PROVIDER="${PROVIDER:-ollama}"
case "$PROVIDER" in
  ollama)
    [[ -n "${MODEL:-}" ]] || { echo "common.sh: MODEL is not set in model_presets/$PRESET.env" >&2; exit 1; }
    ;;
  anthropic)
    # MODEL is unused: the model is chosen at runtime via /model or --model.
    # The claude code token is read from outside the repo so it can never be committed.
    [[ -n "${CLAUDE_TOKEN_FILE:-}" ]] || { echo "common.sh: CLAUDE_TOKEN_FILE is not set in config.env" >&2; exit 1; }
    [[ -r "$CLAUDE_TOKEN_FILE" ]] || { echo "common.sh: no readable token at $CLAUDE_TOKEN_FILE — run 'claude setup-token' on the host and save the token there" >&2; exit 1; }
    CLAUDE_CODE_OAUTH_TOKEN="$(<"$CLAUDE_TOKEN_FILE")"   # $(<f) strips the trailing newline
    [[ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]] || { echo "common.sh: $CLAUDE_TOKEN_FILE is empty" >&2; exit 1; }
    export CLAUDE_CODE_OAUTH_TOKEN
    ;;
  *) echo "common.sh: unknown PROVIDER '$PROVIDER' in model_presets/$PRESET.env (expected 'ollama' or 'anthropic')" >&2; exit 1 ;;
esac

export CIB_ROOT PRESET PROVIDER MODEL IMAGE_NAME OLLAMA_URL OLLAMA_AUTH_TOKEN
export OLLAMA_FLASH_ATTENTION OLLAMA_KV_CACHE_TYPE OLLAMA_CONTEXT_LENGTH OLLAMA_NUM_PARALLEL OLLAMA_KEEP_ALIVE
