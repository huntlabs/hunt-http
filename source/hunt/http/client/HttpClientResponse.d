module hunt.http.client.HttpClientResponse;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpVersion;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.ByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;

alias Response = HttpClientResponse;

class HttpClientResponse : HttpResponse {
	ResponseBody _body;
	
	this(HttpVersion ver, int status, string reason) {
		super(ver, status, reason, new HttpFields(), -1);
	}
	
	this(HttpVersion ver, int status, string reason, HttpFields fields, long contentLength) {
		super(ver, status, reason, fields, contentLength);
	}


  /**
   * Returns a non-null value if this response was passed to {@link Callback#onResponse} or returned
   * from {@link Call#execute()}. Response bodies must be {@linkplain ResponseBody closed} and may
   * be consumed only once.
   *
   * <p>This always returns null on responses returned from {@link #cacheResponse}, {@link
   * #networkResponse}, and {@link #priorResponse()}.
   */
	ResponseBody getBody() {
		return _body;
	}	

	void setBody(ResponseBody b) {
		_body = b;
	}	

}

/**
*/
class ResponseBody {
	ByteBuffer _content;
	string _contentType;
	long _contentLength;


	this(string contentType, long contentLength, ByteBuffer content) {

		if (content is null) throw new NullPointerException("content == null");
		this._content = content;
		this._contentLength = contentLength;
		this._contentType = contentType;
	}

	string contentType() {
		return _contentType;
	}

	size_t contentLength() {
		return _contentLength;
	}

	string asString() {
		if(_content is null)
			return "";

		return BufferUtils.toString(_content);
	}
 }
