module hunt.http.server.http.HttpServerResponse;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

class HttpServerResponse : MetaData.Response {

	this() {
		super(HttpVersion.HTTP_1_1, 0, new HttpFields());
	}

	this(int status, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, fields, contentLength);
	}

	this(int status, string reason, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, reason, fields, contentLength);
	}

}
