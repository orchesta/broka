import os
import sys
import time

from confluent_kafka import Consumer

# The member's name, such as billing-1. Every line the program prints starts with it.
name = sys.argv[1]
# With a number, the program stops abruptly after billing that many rides, as a crash would.
crash_after = int(sys.argv[2]) if len(sys.argv) > 2 else 0

consumer = Consumer({
    "bootstrap.servers": "localhost:19235",
    "group.id": "ride-billing",
    # The name is also the client id, which the group tools show for each member.
    "client.id": name,
    "group.protocol": "consumer",
    "auto.offset.reset": "earliest",
})
consumer.subscribe(["rides.completed"])

billed = 0
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"{name}: error: {msg.error()}")
            continue
        print(f"{name}: {msg.key().decode()}, partition {msg.partition()}, offset {msg.offset()}")
        # Billing a ride takes a second. The producer writes two a second.
        time.sleep(1)
        billed += 1
        if billed == crash_after:
            print(f"{name}: crash", flush=True)
            os._exit(1)  # Skips close() and the commit it makes.
except KeyboardInterrupt:
    pass  # Ctrl+C: leave the loop.
finally:
    # Commits the position after the last ride poll() returned, then leaves the group.
    consumer.close()
