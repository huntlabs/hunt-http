module HttpClientTest;

import hunt.http.client;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.util.DateTime;
import hunt.util.MimeType;

import std.stdio;
import core.runtime;

// string str = runGet("http://10.1.223.222/test.html");
// enum string httpUrl = runGet("http://10.1.223.222:8080/index.html");
// string str = runGet("http://127.0.0.1:8080/json");
// string str = runGet("http://www.putao.com/");

void main(string[] args) {
    // trace_setlogfilename("./hunt-profile.log");
    // profilegc_setlogfilename("./hunt-gc.log");

    testSimpleHttpClient();
    // testHttpClientWithCookie();
    // testHttpClientWithMultipart();
    // testWebSocketClient();
    // testHttpClientWithTLS();
    // testHttpClientWithMutualTLS();
    version (WITH_HUNT_TRACE)
        testOpenTracing();
}

void testSimpleHttpClient() {

    HttpClientTest test = new HttpClientTest();
    scope(exit) {
        test.close();
    }
    try {
        test.testGet();
        // test.testGetHttps();
        // test.testAsynchronousGet();
        // test.testPost();
        // test.testFormPost();

    } catch (Exception ex) {
        warning(ex);
    }
}

void testHttpClientWithCookie() {
    string url = "http://127.0.0.1:8080/session/foo";
    HttpClient client = new HttpClient();
    scope (exit) {
        client.close();
    }

    client.useCookieStore();

    // post
    FormBody formBody = new FormBody.Builder().add("age", 20).build();

    Response response = postForm(client, url, formBody);

    if (response.haveBody()) {
        warningf("response: %s", response.getBody().asString());
    }

    // Cookie[] cookies = response.cookies();
    // foreach(c ; cookies) {
    //     trace(c.toString());
    // }

    // get
    RequestBuilder rb = new RequestBuilder().url(url);
    // rb.cookies(cookies);

    Request request = rb.build();
    response = client.newCall(request).execute();

    if (response !is null) {
        tracef("status code: %d", response.getStatus());
        warning("response: ", response.getBody().asString());
    }
}

void testHttpClientWithMultipart() {
    // Use the imgur image upload API as documented at https://api.imgur.com/endpoints/image
    // string url = "http://127.0.0.1:8080/upload/file";
    string url = "http://10.1.223.222:8080/upload/file";
    HttpClient client = new HttpClient();
    scope (exit) {
        client.close();
    }
    // client.useCookieStore();

    // post
    MultipartBody requestBody = new MultipartBody.Builder() // .setType(MultipartBody.FORM)
    // .enableChunk()
    .addFormDataPart("title",
            "Putao Logo", MimeType.TEXT_PLAIN_VALUE)
        .addFormDataPart("image", "favicon.ico", HttpBody.create("image/ico", "dub.json")) // HttpBody.createFromFile("image/ico", "dub.json"))
        // HttpBody.createFromFile("image/ico", "resources/favicon.ico"))
        .build();

    Response response = postForm(client, url, requestBody);

    if (response.haveBody()) {
        warningf("response: %s", response.getBody().asString());
    }
}

Response postForm(HttpClient client, string url, HttpBody content) {
    Request request = new RequestBuilder().url(url) // .header("Authorization", "Basic cHV0YW86MjAxOQ==")
    .authorization(
            AuthenticationScheme.Basic, "cHV0YW86MjAxOQ==").post(content).build();

    Response response = client.newCall(request).execute();
    return response;
}

void testWebSocketClient() {

    HttpClient client = new HttpClient();
    scope (exit) {
        client.close();
    }
    //
    string url = "http://127.0.0.1:8080/ws1";
    Request request = new RequestBuilder().url(url) // .header("Authorization", "Basic cHV0YW86MjAxOQ==")
    .authorization(
            AuthenticationScheme.Basic, "cHV0YW86MjAxOQ==").build();

    // dfmt off
    WebSocketConnection wsConn = client.newWebSocket(request,
            new class AbstractWebSocketMessageHandler {
                override void onOpen(WebSocketConnection connection) {
                    warning("Connection opened"); connection.sendText(
                        "Hello WebSocket. " ~ DateTime.getTimeAsGMT());}

                    override void onText(WebSocketConnection connection, string text) {
                        warningf("received (from %s): %s", connection.getRemoteAddress(), text);
                    }
                }
    );
    // dfmt on
    // import core.thread;
    // import core.time;
    // Thread.sleep(5.seconds);
    // wsConn.close();
    // client.close();
}

void testHttpClientWithTLS() {
    string url = "https://10.1.223.222:443/";
    // string url = "https://publicobject.com/helloworld.txt";
    // string url = "https://www.bing.com/";

    HttpClient client = new HttpClient();
    scope (exit) {
        client.close();
    }

    Request request = new RequestBuilder().url(url).build();
    Response response = client.newCall(request).execute();

    if (response !is null) {
        tracef("status code: %d", response.getStatus());
        trace(response.getBody().asString());
    }

    warning("done.");
}

void testHttpClientWithMutualTLS() {
    // https://www.naschenweng.info/2018/02/01/java-mutual-ssl-authentication-2-way-ssl-authentication/
    // mutual TLS
    string url = "https://10.1.223.222:443/";
    // string url = "https://publicobject.com/helloworld.txt";
    // string url = "https://www.bing.com/";

    HttpClient client = new HttpClient();
    scope (exit) {
        client.close();
    }

    Request request = new RequestBuilder().url(url).caCert("cert/ca.crt", "hunt2019")
        .mutualTls("cert/client.crt", "cert/client.key", "hunt2019", "hunt2019").build();

    Response response = client.newCall(request).execute();

    if (response !is null) {
        tracef("status code: %d", response.getStatus());
        trace(response.getBody().asString());
    }

    warning("done.");
}

class HttpClientTest {
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    void close() {
        import hunt.net.NetUtil;
        NetUtil.eventLoop.stop();
    }

    // 
    void testGet() {
        string str = runGet("http://10.1.223.222/test.html");
        // string str = runGet("http://10.1.223.222:8080/index.html");
        // string str = runGet("http://127.0.0.1:8080/json");
        // string str = runGet("http://www.putao.com/");
        warning(str);

        trace("===============================");

        // str = runGet("http://10.1.223.222/index.html");
        // str = runGet("http://www.putao.com/");
        // trace(str);
    }

    //
    void testGetHttps() {

        string url = "https://10.1.223.222:440/";
        // string url = "https://publicobject.com/helloworld.txt";
        string str = runGet(url);

        trace(str);
    }

    string runGet(string url) {

        Request request = new RequestBuilder().url(url).build();
        Response response = client.newCall(request).execute();

        if (response !is null) {
            tracef("status code: %d", response.getStatus());
            return response.getBody().asString();
        }

        return "";
    }

    //
    void testAsynchronousGet() {

        // string url = "https://10.1.223.222:6677/index";
        string url = "https://publicobject.com/helloworld.txt";
        Request request = new RequestBuilder().url(url).build();

        // dfmt off
            client.newCall(request).enqueue(new class Callback {
                void onFailure(Call call, IOException e) {
                    warning(e.toString());}

                    void onResponse(Call call, Response response) {
                        HttpBody responseBody = response.getBody(); if (!response.isSuccessful())
                            throw new IOException("Unexpected code " ~ response.toString());

                                HttpFields responseHeaders = response.headers(); foreach (
                                    HttpField header; responseHeaders) {
                                    trace(header.getName() ~ ": " ~ header.getValue());
                                }

                        trace(responseBody.asString());}
                    }
            );
            // dfmt on

        info("A request has been sent.");
    }

    // void testPost() {
    //     UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
    //     encoder.put("email", "test@putao.com");
    //     encoder.put("password", "test");
    //     // string content = "email=test%40putao.com&password=test";
    //     string content = encoder.encode();
    //     string response = post("http://10.1.223.222:8080/testpost",
    //             "application/x-www-form-urlencoded", content);

    //     // string content = `{"type":"news", "offset": "0", "count": "20"}`;
    //     // string url = "https://api.weixin.qq.com/cgi-bin/material/batchget_material?access_token=24_1IgJevIE2nBKEylZUX-eV1AEsPoFOu8Q_5_slFPPbw-Zh4wozxl6vS0DfBgbXDWD8nFu0j6_WVUAS5HvxjBLZBNAg4wzr7dplhfI7O0E9nHQtOdDbcTwZ2UzlPjEUhgEiLSiZ-0qiyPu0DOCXBIfAIAPTA";

    //     // string response = post(url, MimeType.APPLICATION_JSON_UTF_8.toString(), content);

    //     trace(response);
    // }

    void testPost() {

        import core.time;
    
        string[string] postData = [
        "__VIEWSTATE" : "/wEPDwUKLTEwMDYyNTk0N2RkUSZixNmxd0w9kosXl7Hd+TgdQy0=",
        "__VIEWSTATEGENERATOR" : "C2EE9ABB1",
        "login_id" : "18001930082",
        "password" : "putao@521",
        "verify_code" : "",
        "mobile" : "",
        "verification_code" : "",
        "deviceId" : "B32V7RRDLESDBIKHC24V3EWK7IEU2N76ETEGUWRAH6JV2NSAG7YS5NEUKUMCAAJA7SQYAMOAKX45DMR7XSRRXMQBIU",
        "__CALLBACKID" : "ACall",
        "__CALLBACKPARAM" : `{"Method":"Login","CallControl":"{page}"}`
        ];

        UrlEncoded encoder = new UrlEncoded(UrlEncodeStyle.HtmlForm);
        foreach (string name, string value; postData) {
            encoder.put(name, value);
        }
        string content = encoder.encode();

        HttpBody b = HttpBody.create("application/x-www-form-urlencoded", content);
        auto builder = new RequestBuilder()
            .url("https://www.erp321.com/login.aspx")
            .post(b);
        auto request = builder.build();
        auto options = new HttpClientOptions();
        auto clientOptions = options.getTcpConfiguration();
        clientOptions.setConnectTimeout(30.seconds);
        clientOptions.setIdleTimeout(120.seconds);
        HttpClient client = new HttpClient(options);
        Response response = client.newCall(request).execute();
        HttpBody res = response.getBody();
        // logError(res);
        logErrorf("jushuitan response http status code: %d", response.getStatus());
        logError( res.asString());
    }    

    string post(string url, string contentType, string content) {
        HttpBody b = HttpBody.create(contentType, content);

        Request request = new RequestBuilder().url(url).post(b).build();

        Response response = client.newCall(request).execute();
        HttpBody res = response.getBody();
        if (res is null)
            return "";
        else
            return res.asString();
    }

    // 
    void testFormPost() {
        FormBody form = new FormBody.Builder().add("sim", "ple").add("hey",
                "there").add("help", "me").build();

        string response = postForm("http://10.1.11.164:8080/testpost", form);
        // string response = postForm("http://10.1.223.222:8080/testpost", form);
        trace(response);
    }

    string postForm(string url, HttpBody content) {
        Request request = new RequestBuilder().url(url).header("Authorization",
                "Basic cHV0YW86MjAxOQ==").post(content).build();

        Response response = client.newCall(request).execute();
        if (response.haveBody())
            return response.getBody().asString();
        return "";
    }

}

version (WITH_HUNT_TRACE) {
    void testOpenTracing() {
        import hunt.trace.HttpSender;

        // string endpoint = "http://10.1.11.34:9411/api/v2/spans";
        string endpoint = "http://10.1.223.222:9411/api/v2/spans";
        httpSender().endpoint(endpoint);

        // string url = "http://10.1.223.222/index.html";
        string url = "http://127.0.0.1:8080/plaintext";
        HttpClient client = new HttpClient();

        Request request = new RequestBuilder().url(url).localServiceName("HttpClientDemo").build();
        Response response = client.newCall(request).execute();

        if (response !is null) {
            warningf("status code: %d", response.getStatus());
            // if(response.haveBody())
            //  trace(response.getBody().asString());
        } else {
            warning("no response");
        }

        getchar();
    }
}
