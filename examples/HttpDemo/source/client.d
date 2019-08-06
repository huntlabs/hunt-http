
module HttpClientTest;

import hunt.http.client.HttpClient;
import hunt.http.client.HttpClientConnection;
import hunt.http.client.RequestBuilder;
import hunt.http.client.Call;

import hunt.http.client.HttpClientResponse;
import hunt.http.client.HttpClientRequest;
import hunt.http.client.FormBody;
import hunt.http.client.RequestBody;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpField;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.util.MimeType;


import std.stdio;

void main(string[] args) {

    HttpClientTest test = new HttpClientTest();
    test.testGet();
    // test.testGetHttps();
    // test.testAsynchronousGet();
    // test.testPost();
    // test.testFormPost();
}


class HttpClientTest {
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    // 
    void testGet() {
        // string str = runGet("http://10.1.222.120/test.html");
        string str = runGet("http://10.1.222.120:8080/index.html");
        // string str = runGet("http://127.0.0.1:8080/json");
        // string str = runGet("http://www.putao.com/");
        trace(str);
        
        trace("===============================");

        // str = runGet("http://10.1.222.120/index.html");
        // str = runGet("http://www.putao.com/");
        // trace(str);
    }

    //
    void testGetHttps() {
		
        // string url = "https://10.1.222.120:6677/index";
        string url = "https://publicobject.com/helloworld.txt";
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
        
        // string url = "https://10.1.222.120:6677/index";
        string url = "https://publicobject.com/helloworld.txt";
        Request request = new RequestBuilder().url(url).build();

        client.newCall(request).enqueue(new class Callback {
            void onFailure(Call call, IOException e) {
               warning(e.toString());
            }

            void onResponse(Call call, Response response) {
                ResponseBody responseBody = response.getBody();
                if (!response.isSuccessful()) throw new IOException("Unexpected code " ~ response.toString());

                HttpFields responseHeaders = response.headers();
                foreach(HttpField header; responseHeaders) {
                    trace(header.getName() ~ ": " ~ header.getValue());
                }

                trace(responseBody.asString());
            }
        }); 
        info("A request has been sent.");
    }

	// 
    void testPost() {
        import hunt.net.util.UrlEncoded;
        UrlEncoded encoder = new UrlEncoded;
        encoder.put("email", "test@putao.com");
        encoder.put("password", "test");
        // string content = "email=test%40putao.com&password=test";
        string content = encoder.encode();
        string response = post("http://127.0.0.1:8080/testpost", "application/x-www-form-urlencoded", content);
        trace(response);
    }

    string post(string url, string contentType,  string content) {
        RequestBody b = new RequestBody(contentType, content);

        Request request = new RequestBuilder()
            .url(url)
            .post(b)
            .build();

        Response response = client.newCall(request).execute();
        ResponseBody res = response.getBody();
        if(res is null)
            return "";
        else
            return res.asString();
  	}

	// 
    void testFormPost() {
		FormBody form = new FormBody.Builder()
        .add("sim", "ple")
        .add("hey", "there")
        .add("help", "me")
        .build();

        string response = postForm("http://10.1.11.164:8080/testpost", form);
		// string response = postForm("http://10.1.222.120:8080/testpost", form);
        trace(response);
    }

    string postForm(string url, RequestBody content) {
        Request request = new RequestBuilder()
            .url(url)
			.header("Authorization", "Basic cHV0YW86MjAxOQ==")
            .post(content)
            .build();

        Response response = client.newCall(request).execute();
        return response.getBody().asString();
  	}

}
