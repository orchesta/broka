#!/bin/sh
# Runs inside the cli container. $1 is a pack in /work, $2 an optional older pack whose checkpoint to use.
set -u

oam() { npx --yes --package=@openauditmodel/cli@1.0.0 openauditmodel "$@"; }

# unpack <zip>: prints the directory it was unpacked into
unpack() {
  dir=$(mktemp -d)
  unzip -q "/work/$1" -d "$dir"
  echo "$dir"
}

# The events are one events.ndjson or, in later releases, a folder of files; the CLI takes either.
events_of() {
  if [ -d "$1/events" ]; then echo "$1/events"; else echo "$1/events.ndjson"; fi
}

new=$(unpack "$1")
events=$(events_of "$new")
status=0

echo "== verify-chain $1"
oam verify-chain "$events" || status=1

if [ -f "$new/checkpoint.json" ]; then
  echo "== verify-checkpoint, $1 against its own checkpoint"
  oam verify-checkpoint --checkpoint "$new/checkpoint.json" "$events" || status=1
fi

if [ -n "${2:-}" ]; then
  old=$(unpack "$2")
  echo "== verify-checkpoint, $1 against the checkpoint of $2"
  oam verify-checkpoint --checkpoint "$old/checkpoint.json" "$events" || status=1
fi

exit "$status"
