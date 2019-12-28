module hunt.trace.HttpSender;

import hunt.trace.Span;
import hunt.trace.Constrants;

import hunt.http.client;
import hunt.logging.ConsoleLogger;

import std.array;
import std.concurrency : initOnce;
import std.parallelism;

/**
 * Reports spans to Zipkin, using its <a href="https://zipkin.io/zipkin-api/#/">POST</a> endpoint.
 *
 * <h3>Usage</h3>
 *
 * This type is designed for {@link AsyncReporter.Builder#builder(Sender) the async reporter}.
 *
 * <p>Here's a simple configuration, configured for json:
 *
 * <pre>{@code
 * sender = OkHttpSender.create("http://127.0.0.1:9411/api/v2/spans");
 * }</pre>
 *
 * <p>Here's an example that adds <a href="https://github.com/square/okhttp/blob/master/samples/guide/src/main/java/okhttp3/recipes/Authenticate.java">basic
 * auth</a> (assuming you have an authenticating proxy):
 *
 * <pre>{@code
 * credential = Credentials.basic("me", "secure");
 * sender = OkHttpSender.newBuilder()
 *   .endpoint("https://authenticated-proxy/api/v2/spans")
 *   .clientBuilder().authenticator(new Authenticator() {
 *     @Override
 *     public Request authenticate(Route route, Response response) throws IOException {
 *       if (response.request().header("Authorization") != null) {
 *         return null; // Give up, we've already attempted to authenticate.
 *       }
 *       return response.request().newBuilder()
 *         .header("Authorization", credential)
 *         .build();
 *     }
 *   })
 *   .build();
 * }</pre>
 *
 * <h3>Implementation Notes</h3>
 *
 * <p>This sender is thread-safe.
 */
class HttpSender {

    private string _endpoint;
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    this(string endpoint) {
        _endpoint = endpoint;
        client = new HttpClient();
    }

    void endpoint(string value) {
        _endpoint = value;
    }

    void sendSpans(Span[] spans...) {
        if (spans.length == 0) {
            return;
        }

        string str = "[";
        foreach (i, s; spans) {
            str ~= s.toString();
            if (i != spans.length - 1)
                str ~= ",";
        }
        str ~= "]";

        version(HUNT_TRACE_DEBUG) warning(str);
        // doSend(str);
        auto sendTask = task(&doSend, str);
        taskPool.put(sendTask);
    }

    private void doSend(string content) {
        try {

            version(HUNT_HTTP_DEBUG) { 
                tracef("endpoint: %s", _endpoint);
                trace(content);
            }

            assert(!_endpoint.empty());

            RequestBody b = RequestBody.create(MimeType.APPLICATION_JSON_VALUE, content);
            Request request = new RequestBuilder()
                .enableTracing(false)
                .url(_endpoint)
                .post(b)
                .build();
            
            // client = new HttpClient();
            Response response = client.newCall(request).execute();

            if (response !is null) {
                version(HUNT_TRACE_DEBUG) warningf("status code: %d", response.getStatus());
                if(response.haveBody())
                    trace(response.getBody().asString());
            } else {
                warning("no response");
            }
        } catch(Throwable t) {
            warning(t);
        }
    }
}


HttpSender httpSender() {
    __gshared HttpSender inst;
    return initOnce!inst(new HttpSender());
}

