module test1;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.RequestBuilder;
import hunt.http.client.Call;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.codec.http.model.HttpFields;

import hunt.logging.ConsoleLogger;

class HttpClientTest1 {
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    void testGet() {
        string str = run("http://10.1.222.120:8080/index.html");
        trace(str);
    }

    string run(string url) {

        Request request = new RequestBuilder().url(url).build();
        Response response = client.newCall(request).execute();

        if (response !is null) {
            return response.getBody().asString();
        }

        return "";

    }

}
