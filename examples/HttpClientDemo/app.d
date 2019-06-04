module test.codec.http2;

// import java.io.IOException;
// import hunt.concurrency.CopyOnWriteArrayList;
// import hunt.concurrency.Exceptions;
// import hunt.concurrency.Phaser;

import hunt.http.client.ClientHttpHandler;
import hunt.http.client.Http1ClientConnection;
import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.HttpClientRequest;
import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.Cookie;
// import hunt.http.codec.http.model.CookieGenerator;
// import hunt.http.codec.http.model.CookieParser;
// import hunt.http.codec.http.model.HttpField;
// import hunt.http.codec.http.model.HttpHeader;
// import hunt.http.codec.http.model.HttpVersion;
// import hunt.http.codec.http.model.HttpRequest;
// import hunt.http.codec.http.model.HttpResponse;
import hunt.http.codec.http.stream.HttpConfiguration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.HttpOutputStream;
// import hunt.http.utils.VerifyUtils;
import hunt.concurrency.FuturePromise;
import hunt.collection.ArrayList;
import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.collection.List;

import hunt.logging;

import core.thread;
import hunt.net.NetUtil;

void main(string[] args) {

    NetUtil.startEventLoop();

    HttpConfiguration http2Configuration = new HttpConfiguration();
    http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
    HttpClient client = new HttpClient(http2Configuration);

    FuturePromise!HttpClientConnection promise = new FuturePromise!HttpClientConnection();
    client.connect("127.0.0.1", 8080, promise);

    HttpConnection connection;
    
    try {
        connection = promise.get();
    } catch(Exception ex) {
        warning(ex.msg);
        // Thread.sleep(2.seconds);
        NetUtil.stopEventLoop();
        return;
    }
    trace(connection.getHttpVersion());

    if (connection.getHttpVersion() == HttpVersion.HTTP_1_1) {
        Http1ClientConnection http1ClientConnection = cast(Http1ClientConnection) connection;

        // final Phaser phaser = new Phaser(2);

        // request index.html
        HttpClientRequest request = new HttpClientRequest("GET", "/index.html");
        http1ClientConnection.send(request, new class AbstractClientHttpHandler {

            override bool content(ByteBuffer item, Request request, Response response, 
                    HttpOutputStream output, HttpConnection connection) {
                trace(BufferUtils.toString(item));
                return false;
            }

            override
            bool messageComplete(Request request, Response response, HttpOutputStream output,
                    HttpConnection connection) {
                trace(response);
                trace(response.getFields());
                // int currentPhaseNumber = phaser.arrive();
                // trace("current phase number: " ~ currentPhaseNumber);
                return true;
            }

        });
        // phaser.arriveAndAwaitAdvance();

        // List!Cookie currentCookies = new ArrayList!Cookie(); // CopyOnWriteArrayList
        // login
        // HttpClientRequest loginRequest = new HttpClientRequest("GET", "/login");
        // http1ClientConnection.send(loginRequest, new AbstractClientHttpHandler() {

        //     override
        //     bool content(ByteBuffer item, Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(BufferUtils.toString(item));
        //         return false;
        //     }

        //     override
        //     bool messageComplete(Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(response);
        //         trace(response.getFields());
        //         string cookieString = response.getFields().get(HttpHeader.SET_COOKIE);
        //         if (VerifyUtils.isNotEmpty(cookieString)) {
        //             Cookie cookie = CookieParser.parseSetCookie(cookieString);
        //             currentCookies.add(cookie);
        //         }

        //         int currentPhaseNumber = phaser.arrive();
        //         trace("current phase number: " ~ currentPhaseNumber);
        //         return true;
        //     }
        // });
        // phaser.arriveAndAwaitAdvance();

        // trace("current cookies : " ~ currentCookies.toString());
        // post data
        // HttpClientRequest post = new HttpClientRequest("POST", "/add");
        // post.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

        // foreach (Cookie cookie ; currentCookies) {
        //     if (cookie.getName() == "jsessionid") {
        //         post.getFields().add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
        //     }
        // }

        // ByteBuffer data = BufferUtils.toBuffer("content=hello_world".getBytes(StandardCharsets.UTF_8));
        // ByteBuffer data2 = BufferUtils.toBuffer("_data2test".getBytes(StandardCharsets.UTF_8));
        // ByteBuffer[] dataArray = [ data, data2 ];

        // http1ClientConnection.send(post, dataArray, new AbstractClientHttpHandler() {

        //     override
        //     bool content(ByteBuffer item, Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(BufferUtils.toString(item, StandardCharsets.UTF_8));
        //         return false;
        //     }

        //     override
        //     bool messageComplete(Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(response);
        //         trace(response.getFields());
        //         // int currentPhaseNumber = phaser.arrive();
        //         trace("current phase number: " ~ currentPhaseNumber);
        //         return true;
        //     }
        // });
        // phaser.arriveAndAwaitAdvance();

        // post single data
        // HttpClientRequest postSingleData = new HttpClientRequest("POST", "/add");
        // postSingleData.getFields().add(new HttpField(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded"));

        // foreach (Cookie cookie ; currentCookies) {
        //     if (cookie.getName() == "jsessionid") {
        //         postSingleData.getFields()
        //                 .add(new HttpField(HttpHeader.COOKIE, CookieGenerator.generateCookie(cookie)));
        //     }
        // }

        // ByteBuffer data1 = BufferUtils.toBuffer("content=test_post_single_data".getBytes(StandardCharsets.UTF_8));
        // http1ClientConnection.send(post, data1, new AbstractClientHttpHandler() {

        //     override
        //     bool content(ByteBuffer item, Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(BufferUtils.toString(item, StandardCharsets.UTF_8));
        //         return false;
        //     }

        //     override
        //     bool messageComplete(Request request, Response response, HttpOutputStream output,
        //             HttpConnection connection) {
        //         trace(response);
        //         trace(response.getFields());
        //         // int currentPhaseNumber = phaser.arrive();
        //         // trace("current phase number: " ~ currentPhaseNumber);
        //         return true;
        //     }
        // });
        // phaser.arriveAndAwaitAdvance();

        trace("request finished");
        import core.time;
        Thread.sleep(5.seconds);
        http1ClientConnection.close();
        NetUtil.stopEventLoop();
    } else {

    }
}

