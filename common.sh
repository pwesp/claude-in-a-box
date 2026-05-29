#!/usr/bin/env bash
CIB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$CIB_ROOT/config.env"

[[ -n "${PRESET:-}" ]] || { echo "common.sh: PRESET is not set in config.env" >&2; exit 1; }
[[ -f "$CIB_ROOT/model_presets/$PRESET.env" ]] || { echo "common.sh: no preset file for '$PRESET' (expected model_presets/$PRESET.env)" >&2; exit 1; }

source "$CIB_ROOT/model_presets/$PRESET.env"

[[ -n "${MODEL:-}" ]] || { echo "common.sh: MODEL is not set in model_presets/$PRESET.env" >&2; exit 1; }

export CIB_ROOT PRESET MODEL IMAGE_NAME OLLAMA_URL OLLAMA_AUTH_TOKEN
export OLLAMA_FLASH_ATTENTION OLLAMA_KV_CACHE_TYPE OLLAMA_CONTEXT_LENGTH OLLAMA_NUM_PARALLEL OLLAMA_KEEP_ALIVE
