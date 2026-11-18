import os
import sys

from confluent_kafka import Consumer

# With a number, the program stops abruptly after reading that many rides, as a crash would.
crash_after = int(sys.argv[1]) if len(sys.argv) > 1 else 0

consumer = Consumer({
    "bootstrap.servers": "localhost:19233",
    "group.id": "ride-receipts",
    # The newer group protocol, in which the broker runs the group; a later lesson compares the two.
    "group.protocol": "consumer",
    # Where the group starts on a partition it has no committed offset for.
    "auto.offset.reset": "earliest",
})
consumer.subscribe(["rides.completed"])

read = 0
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"error: {msg.error()}")
            continue
        print(f"{msg.key().decode()}: partition {msg.partition()}, offset {msg.offset()}")
        read += 1
        if read == crash_after:
            print("crash", flush=True)
            os._exit(1)  # No close(), no commit.
except KeyboardInterrupt:
    pass  # Ctrl+C: leave the loop.
finally:
    # Commits the position after the last records poll() returned, then leaves the group.
    consumer.close()
