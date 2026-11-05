import json

from confluent_kafka import Producer

producer = Producer({
    "bootstrap.servers": "localhost:19232",
    # Hash keys the way the Java client does, so that a key goes to the same partition from either client.
    "partitioner": "murmur2_random",
    # On by default in the Java client, off by default in this one.
    "enable.idempotence": True,
})


def on_delivery(error, msg):
    record = json.loads(msg.value())
    label = f"{record['bike']} ride {record['ride']} {record['status']}"
    if error is not None:
        print(f"{label} failed: {error}")
    else:
        print(f"{label}: partition {msg.partition()}, offset {msg.offset()}")


for ride in (1, 2):
    for status in ("unlocked", "locked"):
        for bike in ("bike-1001", "bike-1002", "bike-1042", "bike-1234"):
            value = json.dumps({"bike": bike, "ride": ride, "status": status})
            # The key is the bike: every record of one bike goes to the same partition.
            producer.produce("bikes.status", key=bike, value=value, on_delivery=on_delivery)

# flush() waits until every record is sent; the callbacks run inside it.
producer.flush()
