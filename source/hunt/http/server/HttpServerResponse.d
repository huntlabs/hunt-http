module hunt.http.server.HttpServerResponse;

import hunt.http.HttpFields;
import hunt.http.HttpResponse;
import hunt.http.HttpVersion;

class HttpServerResponse : HttpResponse {

	this() {
		super(HttpVersion.HTTP_1_1, 200, new HttpFields());
	}

	this(int status, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, fields, contentLength);
	}

	this(int status, string reason, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, reason, fields, contentLength);
	}

}
