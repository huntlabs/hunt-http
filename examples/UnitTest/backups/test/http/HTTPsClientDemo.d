module test.http;

import hunt.http.$;
import hunt.http.client.http2.SimpleHttpClient;
import hunt.http.codec.http.model.HttpStatus;
import hunt.net.secure.SecureSessionFactory;
import hunt.net.tcp.secure.conscrypt.ConscryptSecureSessionFactory;
import hunt.net.tcp.secure.jdk.JdkSecureSessionFactory;

import java.util.Arrays;
import hunt.collection.List;
import java.util.concurrent.CountDownLatch;

/**
 * 
 */
public class HttpsClientDemo {
    public static final List<string> urlList = Arrays.asList(
            "https://www.jd.com",
            "https://segmentfault.com",
            "https://github.com",
            "https://www.taobao.com",
            "https://www.baidu.com",
            "https://login.taobao.com");

    public static void main(string[] args) throws InterruptedException {
        List<SimpleHttpClient> clients = Arrays.asList(
                test(new ConscryptSecureSessionFactory()),
                test(new JdkSecureSessionFactory()));
        clients.forEach(SimpleHttpClient::stop);
    }

    public static SimpleHttpClient test(SecureSessionFactory secureSessionFactory) throws InterruptedException {
        long testStart = System.currentTimeMillis();
        writeln("The secure session factory is " ~ secureSessionFactory.typeof(this).stringof);
        SimpleHttpClient client = $.createHttpsClient(secureSessionFactory);
        for (int i = 0; i < 5; i++) {
            CountDownLatch latch = new CountDownLatch(urlList.size());
            urlList.forEach(url -> {
                long start = System.currentTimeMillis();
                client.get(url).submit().thenAccept(resp -> {
                    long end = System.currentTimeMillis();
                    if (resp.getStatus() == HttpStatus.OK_200) {
                        writeln("The " ~ url ~ " is OK. " ~
                                "Size: " ~ resp.getStringBody().length ~ ". " ~
                                "Time: " ~ (end - start) ~ ". " ~
                                "Version: " ~ resp.getHttpVersion());
                    } else {
                        writeln("The " ~ url ~ " is failed. " ~
                                "Status: " ~ resp.getStatus() ~ ". " ~
                                "Time: " ~ (end - start) ~ ". " ~
                                "Version: " ~ resp.getHttpVersion());
                    }
                    latch.countDown();
                });
            });
            latch.await();
            writeln("test " ~ i ~ " completion. ");
        }
        long testEnd = System.currentTimeMillis();
        writeln("The secure session factory " ~ secureSessionFactory.typeof(this).stringof ~ " test completed. " ~ (testEnd - testStart));
        return client;
    }
}
