#!/usr/bin/env bash
# Checks the forwarded copy of the trail with the specification's reference CLI.
set -euo pipefail
. "$(dirname "$0")/common.sh"

lab run --rm cli sh -c '
  ls -l /forwarded
  npx --yes --package=@openauditmodel/cli@1.0.0 openauditmodel verify-chain /forwarded
'
