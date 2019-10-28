module hunt.http.server.HttpServerResponse;

import hunt.http.Cookie;

import hunt.http.HttpHeader;
import hunt.http.HttpFields;
import hunt.http.HttpResponse;
import hunt.http.HttpVersion;

/** 
 * 
 */
class HttpServerResponse : HttpResponse {

	this() {
		super(HttpVersion.HTTP_1_1, 200, new HttpFields());
	}

	this(int status, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, fields, contentLength);
	}

	this(int status, string reason) {
		this(status, reason, new HttpFields(), -1);
	}

	this(int status, string reason, HttpFields fields, long contentLength) {
		super(HttpVersion.HTTP_1_1, status, reason, fields, contentLength);
	}

	
    HttpServerResponse addCookie(Cookie cookie) {
        getFields().add(HttpHeader.SET_COOKIE, generateSetCookie(cookie));
        return this;
    }

}
