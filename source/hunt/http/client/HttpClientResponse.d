module hunt.http.client.HttpClientResponse;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

class HttpClientResponse : HttpResponse {
	
	this(HttpVersion ver, int status, string reason) {
		super(ver, status, reason, new HttpFields(), -1);
	}
	
	this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
		super(ver, status, reason, fields, contentLength);
	}

}
