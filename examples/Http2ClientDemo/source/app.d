
import hunt.http.codec.http.model;

import hunt.http.client.http.SimpleHTTPClient;
import hunt.http.client.http.SimpleResponse;

import hunt.util.concurrent.Promise;
import hunt.util.concurrent.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;
import hunt.net.secure.conscrypt;

import hunt.http.helper;
import hunt.datetime;
import hunt.logging;

import std.datetime;
import std.conv;
import std.stdio;

/**
sudo apt-get install libssl-dev
*/

void main(string[] args) {
	SimpleHTTPClient simpleHTTPClient = test(new ConscryptSecureSessionFactory());
	// simpleHTTPClient = test(new JdkSecureSessionFactory());
	simpleHTTPClient.stop();
}


// string[] urlList = ["https://www.putao.com/",
//             "https://segmentfault.com"];

// string[] urlList = ["https://10.1.222.120:446/"];
string[] urlList = ["https://127.0.0.1:8081/"];

long getMillisecond(long v)
{
    return convert!(TimeUnits.HectoNanosecond, TimeUnits.Millisecond)(v);
}

SimpleHTTPClient test(SecureSessionFactory secureSessionFactory) {
    long testStart = Clock.currStdTime;
    tracef("The secure session factory is " ~ typeid(secureSessionFactory).name);
    SimpleHTTPClient client = createHTTPsClient(secureSessionFactory);
    // for (int i = 0; i < 5; i++) {
    //     CountDownLatch latch = new CountDownLatch(urlList.size());
    foreach(string url; urlList)
    {
        long start = Clock.currStdTime;
        client.get(url).submit().thenAccept((SimpleResponse resp) {
            long end = Clock.currStdTime;
            if (resp.getStatus() == HttpStatus.OK_200) {
                tracef("The " ~ url ~ " is OK. " ~
                        "Size: " ~ resp.getStringBody().length.to!string() ~ ". " ~
                        "Time: " ~ getMillisecond(end - start).to!string() ~ ". " ~
                        "Version: " ~ resp.getHttpVersion().toString());
            } else {
                tracef("The " ~ url ~ " is failed. " ~
                        "Status: " ~ resp.getStatus().to!string() ~ ". " ~
                        "Time: " ~ getMillisecond(end - start).to!string() ~ ". " ~
                        "Version: " ~ resp.getHttpVersion().toString());
            }
                // latch.countDown();
        });
    }
			
    //     latch.await();
    //     tracef("test " ~ i.to!string() ~ " completion. ");
    // }
    // long testEnd = Clock.currStdTime;
    // tracef("The secure session factory " ~ typeid(secureSessionFactory).name ~ " test completed. " ~ 
    //     getMillisecond(testEnd - testStart).to!string());
    return client;
}