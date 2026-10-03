#!/usr/bin/env bash
# Checks an evidence pack with the specification's reference CLI, without BROKA:
#   bash scripts/verify.sh <pack.zip> [<older pack.zip>]
# With an older pack, the new pack's events are also checked against the older pack's checkpoint.
set -euo pipefail
. "$(dirname "$0")/common.sh"

pack=$(basename "${1:?usage: verify.sh <pack.zip in evidence/> [<older pack.zip in evidence/>]}")
older=$(basename "${2:-}")
[ -f "evidence/$pack" ] || { echo "evidence/$pack not found" >&2; exit 1; }
[ -z "$older" ] || [ -f "evidence/$older" ] || { echo "evidence/$older not found" >&2; exit 1; }

lab run --rm cli sh /scripts/verify-pack.sh "$pack" "$older"
