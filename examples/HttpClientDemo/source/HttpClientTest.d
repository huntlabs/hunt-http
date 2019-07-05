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

class HttpClientTest {
    HttpClient client;

    this() {
        client = new HttpClient();
    }

    void testGet() {
        // string str = runGet("http://10.1.223.62:8080/test.html");
        string str = runGet("http://10.1.222.120/index.html");
        // string str = runGet("http://127.0.0.1:8080/json");
        // string str = runGet("http://www.putao.com/");
        trace(str);
        
        trace("===============================");

        // str = runGet("http://10.1.222.120/index.html");
        // str = runGet("http://www.putao.com/");
        // trace(str);
    }

    void testGetHttps() {
		
        string url = "https://publicobject.com/helloworld.txt";
        // string url = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=wx142af949a0fa817f&secret=061b677b5cb397c1a69676c6569ef67a&code=071d9qF722BieR0CYOD722HCF72d9qFH&grant_type=authorization_code`;
        // url = "https://10.1.222.120:440/index.html";
        string str = runGet(url);

        // string str = runGet("https://10.1.222.120:6677/index");
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

    void testAsynchronousGet() {
        // Request request = new RequestBuilder().url("http://publicobject.com/helloworld.txt").build();
        
        // string url = "https://10.1.222.120:6677/index";
        string url = "https://publicobject.com/helloworld.txt";
		// string url = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=wx142af949a0fa817f&secret=061b677b5cb397c1a69676c6569ef67a&code=071d9qF722BieR0CYOD722HCF72d9qFH&grant_type=authorization_code`;
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
        string form = "email=test%40test.com&password=test";
        string response = post("http://10.1.222.120:8080/testpost", "application/x-www-form-urlencoded", form);
        trace(response);
    }

    string post(string url, string contentType,  string content) {
        RequestBody b = new RequestBody(contentType, content);

        Request request = new RequestBuilder()
            .url(url)
            .post(b)
            .build();

        Response response = client.newCall(request).execute();
        return response.getBody().asString();
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
