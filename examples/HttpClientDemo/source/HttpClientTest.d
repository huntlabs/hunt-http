module HttpClientTest;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.RequestBuilder;
import hunt.http.client.Call;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.codec.http.model.HttpFields;

import hunt.logging.ConsoleLogger;

class HttpClientTest {
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    void testGet() {
        // string str = runGet("http://10.1.223.62:8080/test.html");
        string str = runGet("http://10.1.222.120/index.html");
        // string str = runGet("http://127.0.0.1:8080/json");
        trace(str);
    }

    void testGetHttps() {
        // string str = runGet("https://10.1.222.120:444/index.html");

        string str = runGet("https://10.1.222.120:6677/index");
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

    void testPost() {
        string form = "email=test%40test.com&password=test";
        string response = post("http://10.1.223.62:8180/testpost", form);
        trace(response);
    }

    string post(string url, string content) {
        string mimeType = "application/x-www-form-urlencoded";
        RequestBody b = new RequestBody(mimeType, content);

        Request request = new RequestBuilder()
            .url(url)
            .post(b)
            .build();

        Response response = client.newCall(request).execute();
        return response.getBody().asString();
  }

}
