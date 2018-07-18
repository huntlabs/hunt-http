module test.http;

import hunt.http.client.http2.SimpleHTTPClient;

public class SimpleHTTPClientDemo3 {

	public static void main(string[] args) {
		SimpleHTTPClient client = new SimpleHTTPClient();
		client.post("http://localhost:3322/testPost").body("test post data, hello").submit(r -> {
			writeln(r.getResponse().toString());
			writeln(r.getResponse().getFields());
			writeln(r.getStringBody());
		});
		
		client.get("http://localhost:3322/index").submit(r -> {
			writeln(r.getResponse().toString());
			writeln(r.getResponse().getFields());
			writeln(r.getStringBody());
		});
	}

}
