module hunt.http.client.HttpClientRequest;

import hunt.http.client.RequestBody;
import hunt.http.client.RequestBuilder;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.HttpVersion;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.ByteBuffer;
import hunt.collection.HeapByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;

alias Request = HttpClientRequest;

/**
*/
class HttpClientRequest : HttpRequest {

	private RequestBody _body;

	this(string method, string uri) {
		HttpFields fields = new HttpFields();
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, fields);
	}

	this(string method, string uri, RequestBody content) {
		this._body = content;
		HttpFields fields = new HttpFields();
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());

		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, fields,  
			content is null ? 0 : content.contentLength());
	}
	
	this(string method, HttpURI uri, HttpFields fields, RequestBody content) {
		this._body = content;
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());

		super(method, uri, HttpVersion.HTTP_1_1, fields, 
			content is null ? 0 : content.contentLength());
	}
	
	this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, RequestBody content) {
		this._body = content;
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());
			
		super(method, uri, ver, fields,  
			content is null ? 0 : content.contentLength());
	}

	this(HttpRequest request) {
		super(request);
	}

	RequestBody getBody() {
		return _body;
	}

	RequestBuilder newBuilder() {
		return new RequestBuilder(this);
	}
}
