#!/usr/bin/env bash
# OpenClaw Standalone - R2 old-version cleanup
#
# Usage:
#   CLOUDFLARE_ACCOUNT_ID=xxx CLOUDFLARE_API_TOKEN=xxx bash scripts/cleanup-r2.sh [keep_count]
#
# Optional environment variables:
#   DRY_RUN=true|false             Preview deletions without deleting. Default: false
#   R2_BUCKET=clawpanel-releases   R2 bucket name
#   R2_PREFIX=openclaw-standalone  Root object prefix

set -euo pipefail

KEEP_COUNT="${1:-3}"
DRY_RUN="${DRY_RUN:-false}"
BUCKET="${R2_BUCKET:-clawpanel-releases}"
ROOT_PREFIX="${R2_PREFIX:-openclaw-standalone}"
API_BASE="https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}/r2/buckets/${BUCKET}/objects"

if ! [[ "$KEEP_COUNT" =~ ^[0-9]+$ ]] || [ "$KEEP_COUNT" -lt 1 ]; then
  echo "KEEP_COUNT must be a positive integer." >&2
  exit 1
fi

for cmd in curl jq sort awk grep; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

urlencode() {
  jq -nr --arg value "$1" '$value|@uri'
}

api_get() {
  local prefix="$1"
  local cursor="${2:-}"
  local url="${API_BASE}?prefix=$(urlencode "$prefix")&per_page=1000"

  if [ -n "$cursor" ]; then
    url="${url}&cursor=$(urlencode "$cursor")"
  fi

  curl -fsS \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}" \
    "$url"
}

api_delete() {
  local key="$1"
  local response

  response="$(curl -fsS \
    -X DELETE \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}" \
    "${API_BASE}/${key}")"

  if [ "$(jq -r '.success' <<<"$response")" != "true" ]; then
    echo "Failed to delete: $key" >&2
    echo "$response" | jq -c '{errors, messages}' >&2
    return 1
  fi
}

list_keys() {
  local prefix="$1"
  local cursor=""
  local response
  local truncated

  while :; do
    response="$(api_get "$prefix" "$cursor")"

    if [ "$(jq -r '.success' <<<"$response")" != "true" ]; then
      echo "Failed to list objects for prefix: $prefix" >&2
      echo "$response" | jq -c '{errors, messages}' >&2
      return 1
    fi

    jq -r '.result[]?.key // empty' <<<"$response"

    truncated="$(jq -r '.result_info.is_truncated // false' <<<"$response")"
    cursor="$(jq -r '.result_info.cursor // empty' <<<"$response")"
    if [ "$truncated" != "true" ] || [ -z "$cursor" ]; then
      break
    fi
  done
}

cleanup_edition() {
  local edition="$1"
  local edition_prefix="${ROOT_PREFIX}/${edition}/"
  local keys_file
  local versions_file
  local keep_file
  local delete_file

  keys_file="$(mktemp)"
  versions_file="$(mktemp)"
  keep_file="$(mktemp)"
  delete_file="$(mktemp)"

  echo ""
  echo "=== Edition: $edition ==="
  echo "Prefix: $edition_prefix"

  list_keys "$edition_prefix" >"$keys_file"

  awk -F/ -v root="$ROOT_PREFIX" -v edition="$edition" \
    '$1 == root && $2 == edition && NF >= 4 { print $3 }' "$keys_file" \
    | sort -Vu | sort -Vr >"$versions_file"

  if [ ! -s "$versions_file" ]; then
    echo "No versioned objects found."
    rm -f "$keys_file" "$versions_file" "$keep_file" "$delete_file"
    return 0
  fi

  head -n "$KEEP_COUNT" "$versions_file" >"$keep_file"
  tail -n +"$((KEEP_COUNT + 1))" "$versions_file" >"$delete_file" || true

  echo "Keep latest $KEEP_COUNT version(s):"
  sed 's/^/  keep /' "$keep_file"

  if [ ! -s "$delete_file" ]; then
    echo "No old versions to delete."
    rm -f "$keys_file" "$versions_file" "$keep_file" "$delete_file"
    return 0
  fi

  echo "Old versions:"
  sed 's/^/  old  /' "$delete_file"

  while IFS= read -r version; do
    [ -n "$version" ] || continue

    echo ""
    echo "Deleting version: $edition/$version"

    grep -F "${edition_prefix}${version}/" "$keys_file" | while IFS= read -r key; do
      [ -n "$key" ] || continue
      if [ "$DRY_RUN" = "true" ]; then
        echo "  dry-run rm $key"
      else
        echo "  rm $key"
        api_delete "$key"
      fi
    done
  done <"$delete_file"

  rm -f "$keys_file" "$versions_file" "$keep_file" "$delete_file"
}

echo "=== OpenClaw Standalone R2 Cleanup ==="
echo "Bucket: $BUCKET"
echo "Root prefix: $ROOT_PREFIX"
echo "Keep latest: $KEEP_COUNT version(s) per edition"
echo "Dry run: $DRY_RUN"

cleanup_edition "zh"
cleanup_edition "en"

echo ""
echo "=== Cleanup complete ==="
