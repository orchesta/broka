package learn;

import java.util.Properties;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

public class SearchProducer {
    public static void main(String[] args) {
        var props = new Properties();
        props.put("bootstrap.servers", "localhost:19232");
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());

        int count = 1000;
        int[] partitionOf = new int[count];

        try (var producer = new KafkaProducer<String, String>(props)) {
            for (int n = 0; n < count; n++) {
                int i = n;
                var value = String.format("{\"search\": %d, \"near\": \"station-%d\"}", n, n % 40);
                // No key: the producer chooses the partition.
                var record = new ProducerRecord<String, String>("app.searches", value);
                producer.send(record, (meta, error) -> partitionOf[i] = error == null ? meta.partition() : -1);
            }
        }

        // Print each run of consecutive records that went to the same partition.
        int start = 0;
        for (int n = 1; n <= count; n++) {
            if (n == count || partitionOf[n] != partitionOf[start]) {
                System.out.println("records " + start + " to " + (n - 1) + ": partition " + partitionOf[start]);
                start = n;
            }
        }
    }
}
