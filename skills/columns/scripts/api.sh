#!/usr/bin/env bash
#
# Shared API caller for all rkit:* skills.
# Usage: api.sh METHOD PATH [BODY]
#
# Reads credentials from ~/.config/resultkit/config.json
# Returns JSON: { "status": <int>, "body": <object> }
# On error:    { "status": 0, "error": "<ERROR_CODE>" }
#
# --- Multiple accounts -------------------------------------------------------
# One person can hold logins to more than one ResultMaps org — a consultant with
# their own account and a client's, say — and those live on different teams that
# each token cannot see. Selecting between them by rewriting config.json does not
# work: two Claude sessions in two repos run at once, and whichever wrote last
# decides where BOTH of them post.
#
# So the account is chosen by environment, which is per-process and therefore
# per-session. Set it once per project (`.claude/settings.json` → `env`) and the
# repo you are working in picks the account:
#
#   RESULTKIT_PROFILE=mender   → ~/.config/resultkit/profiles/mender.json
#   RESULTKIT_CONFIG=/path.json → exactly that file (wins over PROFILE)
#   neither                     → ~/.config/resultkit/config.json, as before
#
# A named profile that does not exist is an ERROR, never a fall-back to the
# default account. Falling back is the one behaviour worth ruling out: it would
# post one org's work to another org's board and report success.
set -euo pipefail

CONFIG_DIR="${RESULTKIT_CONFIG_DIR:-$HOME/.config/resultkit}"

if [ -n "${RESULTKIT_CONFIG:-}" ]; then
  CONFIG_FILE="$RESULTKIT_CONFIG"
elif [ -n "${RESULTKIT_PROFILE:-}" ]; then
  # A profile name is a single filename component. Anything else — a slash, a
  # `..`, an empty string — is refused rather than resolved, so the variable
  # cannot be used to read a file outside the profiles directory.
  case "$RESULTKIT_PROFILE" in
    ""|.|..|*[!A-Za-z0-9._-]*)
      echo '{"status":0,"error":"BAD_PROFILE"}'
      exit 0
      ;;
  esac
  CONFIG_FILE="${CONFIG_DIR}/profiles/${RESULTKIT_PROFILE}.json"
else
  CONFIG_FILE="${CONFIG_DIR}/config.json"
fi

# --- Argument parsing ---
if [ $# -lt 2 ]; then
  echo '{"status":0,"error":"USAGE: api.sh METHOD PATH [BODY]"}'
  exit 1
fi

METHOD="$1"
API_PATH="$2"
BODY="${3:-}"

# --- Config loading ---
# `config_file` rides along on both failures. The error CODES are unchanged, so
# existing callers that match on them keep working; the path is additive, and
# without it a mistyped RESULTKIT_PROFILE is indistinguishable from having never
# run /rkit:setup at all.
if [ ! -f "$CONFIG_FILE" ]; then
  printf '{"status":0,"error":"NO_CONFIG","config_file":%s}\n' \
    "$(printf '%s' "$CONFIG_FILE" | jq -Rs .)"
  exit 0
fi

API_TOKEN=$(jq -r '.api_token // empty' "$CONFIG_FILE" 2>/dev/null)
API_BASE=$(jq -r '.api_base // "https://api.resultmaps.com/api/v2"' "$CONFIG_FILE" 2>/dev/null)

if [ -z "$API_TOKEN" ]; then
  printf '{"status":0,"error":"NO_TOKEN","config_file":%s}\n' \
    "$(printf '%s' "$CONFIG_FILE" | jq -Rs .)"
  exit 0
fi

# Strip trailing slash from base URL
API_BASE="${API_BASE%/}"

# --- Build URL ---
# If path starts with /api/ (e.g. /api/v1/...), use only the origin (scheme+host)
# so V1 endpoints work alongside the default /api/v2 base.
if [[ "$API_PATH" == /api/* ]]; then
  API_ORIGIN=$(echo "$API_BASE" | sed 's|^\(https\?://[^/]*\).*|\1|')
  URL="${API_ORIGIN}${API_PATH}"
else
  URL="${API_BASE}${API_PATH}"
fi

CURL_ARGS=(
  -s
  -w '\n%{http_code}'
  -H "Authorization: Bearer ${API_TOKEN}"
  -H "Content-Type: application/json"
  -H "Accept: application/json"
  -X "$METHOD"
)

if [ -n "$BODY" ]; then
  CURL_ARGS+=(-d "$BODY")
fi

# --- Execute request ---
RESPONSE=$(curl "${CURL_ARGS[@]}" "$URL" 2>/dev/null) || {
  echo '{"status":0,"error":"CURL_FAILED"}'
  exit 0
}

# --- Parse response ---
# Last line is HTTP status code, everything before is the body
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
RESP_BODY=$(echo "$RESPONSE" | sed '$d')

# Validate HTTP code is numeric
if ! [[ "$HTTP_CODE" =~ ^[0-9]+$ ]]; then
  echo '{"status":0,"error":"CURL_FAILED"}'
  exit 0
fi

# Validate response body is valid JSON, fall back to wrapping as string
if echo "$RESP_BODY" | jq empty 2>/dev/null; then
  echo "{\"status\":${HTTP_CODE},\"body\":${RESP_BODY}}"
else
  # Non-JSON response — wrap as string
  ESCAPED=$(echo "$RESP_BODY" | jq -Rs .)
  echo "{\"status\":${HTTP_CODE},\"body\":${ESCAPED}}"
fi
