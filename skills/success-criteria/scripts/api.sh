#!/usr/bin/env bash
#
# Shared API caller for all rkit:* skills.
# Usage: api.sh METHOD PATH [BODY]
#
# Reads credentials from ~/.config/resultkit/config.json
# Returns JSON: { "status": <int>, "body": <object> }
# On error:    { "status": 0, "error": "<ERROR_CODE>" }

set -euo pipefail

CONFIG_FILE="$HOME/.config/resultkit/config.json"

# --- Argument parsing ---
if [ $# -lt 2 ]; then
  echo '{"status":0,"error":"USAGE: api.sh METHOD PATH [BODY]"}'
  exit 1
fi

METHOD="$1"
API_PATH="$2"
BODY="${3:-}"

# --- Config loading ---
if [ ! -f "$CONFIG_FILE" ]; then
  echo '{"status":0,"error":"NO_CONFIG"}'
  exit 0
fi

API_TOKEN=$(jq -r '.api_token // empty' "$CONFIG_FILE" 2>/dev/null)
API_BASE=$(jq -r '.api_base // "https://api.resultmaps.com/api/v2"' "$CONFIG_FILE" 2>/dev/null)

if [ -z "$API_TOKEN" ]; then
  echo '{"status":0,"error":"NO_TOKEN"}'
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
