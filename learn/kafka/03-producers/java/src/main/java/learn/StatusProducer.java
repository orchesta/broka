package learn;

import java.util.Properties;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

public class StatusProducer {
    public static void main(String[] args) {
        var props = new Properties();
        props.put("bootstrap.servers", "localhost:19232");
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());

        String[] bikes = {"bike-1001", "bike-1002", "bike-1042", "bike-1234"};

        try (var producer = new KafkaProducer<String, String>(props)) {
            for (int ride = 1; ride <= 2; ride++) {
                for (String status : new String[] {"unlocked", "locked"}) {
                    for (String bike : bikes) {
                        var value = String.format(
                                "{\"bike\": \"%s\", \"ride\": %d, \"status\": \"%s\"}", bike, ride, status);
                        var label = bike + " ride " + ride + " " + status;
                        // The key is the bike: every record of one bike goes to the same partition.
                        var record = new ProducerRecord<>("bikes.status", bike, value);
                        producer.send(record, (meta, error) -> {
                            if (error != null) {
                                System.out.println(label + " failed: " + error);
                            } else {
                                System.out.println(label + ": partition " + meta.partition()
                                        + ", offset " + meta.offset());
                            }
                        });
                    }
                }
            }
        } // close() waits until every record is sent and its callback has run.
    }
}
