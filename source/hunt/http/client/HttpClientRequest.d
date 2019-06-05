module hunt.http.client.HttpClientRequest;

import hunt.http.client.RequestBuilder;

import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpURI;
import hunt.http.codec.http.model.HttpVersion;
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
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields());
	}

	this(string method, string uri, RequestBody content) {
		this._body = content;
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, new HttpFields(),  
			content is null ? 0 : content.contentLength());
	}
	
	this(string method, HttpURI uri, HttpFields fields, RequestBody content) {
		this._body = content;
		super(method, uri, HttpVersion.HTTP_1_1, fields, 
			content is null ? 0 : content.contentLength());
	}
	
	this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, RequestBody content) {
		this._body = content;
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

/**
*/
class RequestBody {
	ByteBuffer _content;
	string _contentType;
	long _contentLength;

	this(string contentType, string content) {
		ByteBuffer buffer = new HeapByteBuffer(cast(byte[])content, 0, cast(int)content.length);
		this(contentType, cast(long)content.length, buffer);
	}

	this(string contentType, long contentLength, ByteBuffer content) {

		if (content is null) throw new NullPointerException("content == null");
		this._content = content;
		this._contentLength = contentLength;
		this._contentType = contentType;
	}

	string contentType() {
		return _contentType;
	}

	long contentLength() {
		return _contentLength;
	}

	ByteBuffer content() {
		return _content;
	}

	// string asString() {
	// 	if(_content is null)
	// 		return "";

	// 	return BufferUtils.toString(_content);
	// }	
}