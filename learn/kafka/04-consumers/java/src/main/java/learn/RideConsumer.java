package learn;

import java.time.Duration;
import java.util.List;
import java.util.Properties;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.errors.WakeupException;
import org.apache.kafka.common.serialization.StringDeserializer;

public class RideConsumer {
    public static void main(String[] args) {
        // With a number, the program stops abruptly after reading that many rides, as a crash would.
        int crashAfter = args.length > 0 ? Integer.parseInt(args[0]) : 0;

        var props = new Properties();
        props.put("bootstrap.servers", "localhost:19233");
        props.put("group.id", "ride-receipts");
        // The newer group protocol, in which the broker runs the group; a later lesson compares the two.
        props.put("group.protocol", "consumer");
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        // Where the group starts on a partition it has no committed offset for.
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
            consumer.subscribe(List.of("rides.completed"));
            int read = 0;
            while (true) {
                for (var record : consumer.poll(Duration.ofSeconds(1))) {
                    System.out.println(record.key() + ": partition " + record.partition()
                            + ", offset " + record.offset());
                    if (++read == crashAfter) {
                        System.out.println("crash");
                        Runtime.getRuntime().halt(1); // No close(), no commit.
                    }
                }
            }
        } catch (WakeupException e) {
            // Ctrl+C: leave the loop.
        } finally {
            // Commits the position after the last records poll() returned, then leaves the group.
            consumer.close();
        }
    }
}
