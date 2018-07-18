module hunt.http.client.http.HTTPClientResponse;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

class HTTPClientResponse : MetaData.Response {
	
	this(HttpVersion ver, int status, string reason) {
		super(ver, status, reason, new HttpFields(), -1);
	}
	
	this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
		super(ver, status, reason, fields, contentLength);
	}

}
