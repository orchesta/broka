package learn;

import java.time.Duration;
import java.util.List;
import java.util.Properties;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.errors.WakeupException;
import org.apache.kafka.common.serialization.StringDeserializer;

public class BillingConsumer {
    public static void main(String[] args) throws InterruptedException {
        // The member's name, such as billing-1. Every line the program prints starts with it.
        String name = args[0];
        // With a number, the program stops abruptly after billing that many rides, as a crash would.
        int crashAfter = args.length > 1 ? Integer.parseInt(args[1]) : 0;

        var props = new Properties();
        props.put("bootstrap.servers", "localhost:19235");
        props.put("group.id", "ride-billing");
        // The name is also the client id, which the group tools show for each member.
        props.put("client.id", name);
        props.put("group.protocol", "consumer");
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        props.put("auto.offset.reset", "earliest");
        // One ride per poll(), as in Python. Billing is slow, and the client leaves the group when more than
        // five minutes pass between two calls of poll(); 500 rides, the default, would take eight minutes.
        props.put("max.poll.records", "1");

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
            int billed = 0;
            while (true) {
                for (var record : consumer.poll(Duration.ofSeconds(1))) {
                    System.out.println(name + ": " + record.key() + ", partition " + record.partition()
                            + ", offset " + record.offset());
                    // Billing a ride takes a second. The producer writes two a second.
                    Thread.sleep(1000);
                    if (++billed == crashAfter) {
                        System.out.println(name + ": crash");
                        Runtime.getRuntime().halt(1); // Skips close() and the commit it makes.
                    }
                }
            }
        } catch (WakeupException e) {
            // Ctrl+C: leave the loop.
        } finally {
            // Commits the position after the last ride poll() returned, then leaves the group.
            consumer.close();
        }
    }
}
