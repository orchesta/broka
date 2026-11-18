import sys

from confluent_kafka import Consumer

# The member's name, such as billing-1. Every line the program prints starts with it.
name = sys.argv[1]

config = {
    "bootstrap.servers": "localhost:19234",
    "group.id": "ride-billing",
    # The name is also the client id, which the group tools show for each member.
    "client.id": name,
    "group.protocol": "consumer",
    "auto.offset.reset": "earliest",
}
# An optional second argument asks the broker for an assignor: uniform or range.
if len(sys.argv) > 2:
    config["group.remote.assignor"] = sys.argv[2]
consumer = Consumer(config)


def numbers(partitions):
    return sorted(p.partition for p in partitions)


# The callbacks print each change to this member's partitions.
consumer.subscribe(
    ["rides.completed"],
    on_assign=lambda c, partitions: print(f"{name}: assigned {numbers(partitions)}"),
    on_revoke=lambda c, partitions: print(f"{name}: revoked {numbers(partitions)}"),
)

try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"{name}: error: {msg.error()}")
            continue
        print(f"{name}: {msg.key().decode()}, partition {msg.partition()}, offset {msg.offset()}")
except KeyboardInterrupt:
    pass  # Ctrl+C: leave the loop.
finally:
    # Commits the position, gives the partitions back and leaves the group.
    consumer.close()
