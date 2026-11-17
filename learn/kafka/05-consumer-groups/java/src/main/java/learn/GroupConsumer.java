package learn;

import java.time.Duration;
import java.util.Collection;
import java.util.List;
import java.util.Properties;
import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.errors.WakeupException;
import org.apache.kafka.common.serialization.StringDeserializer;

public class GroupConsumer {
    public static void main(String[] args) {
        // The member's name, such as billing-1. Every line the program prints starts with it.
        String name = args[0];

        var props = new Properties();
        props.put("bootstrap.servers", "localhost:19234");
        props.put("group.id", "ride-billing");
        // The name is also the client id, which the group tools show for each member.
        props.put("client.id", name);
        props.put("group.protocol", "consumer");
        // An optional second argument asks the broker for an assignor: uniform or range.
        if (args.length > 1) {
            props.put("group.remote.assignor", args[1]);
        }
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        props.put("auto.offset.reset", "earliest");

        var consumer = new KafkaConsumer<String, String>(props);
        var main = Thread.currentThread();
        // Ctrl+C runs this hook: it wakes poll() up and waits until the loop below has closed the consumer.
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            consumer.wakeup();
            try {
                main.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }));

        try {
            // The listener prints each change to this member's partitions.
            consumer.subscribe(List.of("rides.completed"), new ConsumerRebalanceListener() {
                @Override
                public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
                    System.out.println(name + ": assigned " + numbers(partitions));
                }

                @Override
                public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
                    System.out.println(name + ": revoked " + numbers(partitions));
                }
            });
            while (true) {
                for (var record : consumer.poll(Duration.ofSeconds(1))) {
                    System.out.println(name + ": " + record.key() + ", partition " + record.partition()
                            + ", offset " + record.offset());
                }
            }
        } catch (WakeupException e) {
            // Ctrl+C: leave the loop.
        } finally {
            // Commits the position, gives the partitions back and leaves the group.
            consumer.close();
        }
    }

    private static List<Integer> numbers(Collection<TopicPartition> partitions) {
        return partitions.stream().map(TopicPartition::partition).sorted().toList();
    }
}
