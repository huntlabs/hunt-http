import hunt.http.codec.http.model;

import hunt.http.client;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.HttpOutputStream;
import hunt.http.codec.websocket.frame;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketPolicy;

import hunt.concurrency.Promise;
import hunt.concurrency.Future;
import hunt.concurrency.FuturePromise;
import hunt.concurrency.CompletableFuture;

import hunt.net.secure.SecureSessionFactory;
import hunt.net.secure.conscrypt;

import hunt.util.DateTime;
import hunt.logging;

// import std.datetime;
import std.conv;
import std.stdio;

/**
sudo apt-get install libssl-dev
https://github.com/square/okhttp/blob/26949cf4786828157f95e6f954596a1aa530e5e4/samples/guide/src/main/java/okhttp3/recipes/WebSocketEcho.java
*/
void main(string[] args) {

    HttpClient client = new HttpClient();
//
    string url = "http://127.0.0.1:8080/ws1";
    Request request = new RequestBuilder()
        .url(url)
        // .header("Authorization", "Basic cHV0YW86MjAxOQ==")
        .authorization(AuthenticationScheme.Basic, "cHV0YW86MjAxOQ==")
        .build();

    WebSocketConnection wsConn =  client.newWebSocket(request, new class AbstractWebSocketMessageHandler {
        override void onOpen(WebSocketConnection connection) {
            warning("Connection opened");
            connection.sendText("Hello WebSocket. " ~ DateTime.getTimeAsGMT());
        }

        override void onText(string text, WebSocketConnection connection) {
            warningf("received (from %s): %s", connection.getRemoteAddress(), text); 
        }
    });
}
