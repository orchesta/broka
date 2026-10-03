#!/usr/bin/env bash
# Asks BROKA to delete the consumer group order-service without a reason, as a script that forgot one would:
#   bash scripts/refuse.sh <API token> [connection name]
set -euo pipefail
. "$(dirname "$0")/common.sh"

token="${1:?usage: refuse.sh <API token> [connection name]}"
lab run --rm -e BROKA_TOKEN="$token" cli node /scripts/refuse.mjs "${2:-lab-audit}"
