module hunt.http.client.HttpClientResponse;

import hunt.http.Cookie;
import hunt.http.HttpHeader;
import hunt.http.HttpFields;
import hunt.http.HttpVersion;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;


import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.Exceptions;

import std.algorithm;
import std.array;

alias Response = HttpClientResponse;

/**
 * 
 */
class HttpClientResponse : HttpResponse {

	private Cookie[] _cookies;
	
	this(HttpVersion ver, int status, string reason) {
		this(ver, status, reason, new HttpFields(), long.min);
	}
	
	this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
		super(ver, status, reason, fields, contentLength);
	}


	/** Returns true if this response redirects to another resource. */
	bool isRedirect() {
		switch (_status) {
			case HttpStatus.PERMANENT_REDIRECT_308:
			case HttpStatus.TEMPORARY_REDIRECT_307:
			case HttpStatus.MULTIPLE_CHOICES_300:
			case HttpStatus.MOVED_PERMANENTLY_301:
			case HttpStatus.MOVED_TEMPORARILY_302:
			case HttpStatus.SEE_OTHER_303:
				return true;
				
			default:
				return false;
		}
	}
	
	Cookie[] cookies() {
        if (_cookies is null) {
            _cookies = getFields().getValuesList(HttpHeader.SET_COOKIE)
					.map!(parseSetCookie).array;
        }
		
		return _cookies;
    }

}
