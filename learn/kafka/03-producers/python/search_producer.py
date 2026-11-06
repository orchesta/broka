import json

from confluent_kafka import Producer

# No partitioner setting: without a key there is nothing to hash.
producer = Producer({"bootstrap.servers": "localhost:19232"})

# Fetch the topic's partitions before producing, as the Java client's first send() does.
producer.list_topics("app.searches", timeout=10)

count = 1000
partition_of = [None] * count


def on_delivery(error, msg):
    n = json.loads(msg.value())["search"]
    partition_of[n] = msg.partition() if error is None else -1


for n in range(count):
    value = json.dumps({"search": n, "near": f"station-{n % 40}"})
    # No key: the producer chooses the partition.
    producer.produce("app.searches", value=value, on_delivery=on_delivery)

producer.flush()

# Print each run of consecutive records that went to the same partition.
start = 0
for n in range(1, count + 1):
    if n == count or partition_of[n] != partition_of[start]:
        print(f"records {start} to {n - 1}: partition {partition_of[start]}")
        start = n
