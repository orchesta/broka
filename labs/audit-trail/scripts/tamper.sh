#!/usr/bin/env bash
# Rewrites the reason on the newest audit event that has one, directly in the database, the way anyone with
# write access to it could. The seal is left as it was.
set -euo pipefail
. "$(dirname "$0")/common.sh"

reason="${1:-Approved by the change board}"

changed=$(lab exec -T postgres psql -U broka -d broka -v ON_ERROR_STOP=1 -v reason="$reason" -q -A -t << 'SQL'
UPDATE "AuditLog"
SET "Event" = jsonb_set("Event", '{reason,text}', to_jsonb(:'reason'::text))
WHERE "Id" = (
  SELECT "Id" FROM "AuditLog"
  WHERE "Event" #> '{reason,text}' IS NOT NULL
  ORDER BY "At" DESC
  LIMIT 1
)
RETURNING "EventName" || ' at ' || "At" || ': reason now "' || ("Event" #>> '{reason,text}') || '"';
SQL
)

if [ -z "$changed" ]; then
  echo "no audit event carries a reason yet; do one of the destructive steps first" >&2
  exit 1
fi
echo "changed $changed"
