// Deletes a consumer group through BROKA's API without the reason a destructive operation needs.
const base = process.env.BROKA_URL ?? 'http://ui:8080';
const headers = { Authorization: `Bearer ${process.env.BROKA_TOKEN}` };
const connectionName = process.argv[2] ?? 'lab-audit';
const group = 'order-service';

const listed = await fetch(`${base}/api/v1/connections?pageSize=200`, { headers });
if (!listed.ok) {
  console.error(`listing connections: HTTP ${listed.status} ${await listed.text()}`);
  process.exit(1);
}
const body = await listed.json();
const items = body.data?.items ?? body.data ?? [];
const connection = items.find((c) => c.name === connectionName);
if (!connection) {
  console.error(`no connection named ${connectionName}`);
  process.exit(1);
}

const response = await fetch(`${base}/api/v1/connections/${connection.id}/groups/${group}`, {
  method: 'DELETE',
  headers,
});
console.log(`DELETE consumer group ${group} without a reason: HTTP ${response.status}`);
console.log(await response.text());
