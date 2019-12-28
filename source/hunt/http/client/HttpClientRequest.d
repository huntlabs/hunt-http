module hunt.http.client.HttpClientRequest;

import hunt.http.client.RequestBody;
import hunt.http.client.RequestBuilder;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.HttpVersion;
import hunt.http.codec.http.model.MetaData;

import hunt.collection.ByteBuffer;
import hunt.collection.HeapByteBuffer;
import hunt.collection.BufferUtils;
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.Exceptions;

alias Request = HttpClientRequest;

import std.conv;

version(WITH_HUNT_TRACE) {
    import hunt.trace.Constrants;
    import hunt.trace.Endpoint;
    import hunt.trace.Span;
    import hunt.trace.Tracer;
    import hunt.trace.HttpSender;
}


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

    bool isTracingEnabled() {
        return _isTracingEnabled;
    }

    void isTracingEnabled(bool flag) {
        _isTracingEnabled = flag;
    }

	// Trace
	// HttpClientRequest enableTracing(bool flag) {
	// 	_isTracingEnabled = flag;
	// 	return this;
	// }
	
version(WITH_HUNT_TRACE) {
    private bool _isTracingEnabled = true;
    package(hunt.http.client)  Tracer _tracer;
    package(hunt.http.client)  Span _span;
    private string[string] tags;

    void startSpan() {
        if(!isTracingEnabled()) return;
        if(_span is null) {
            warning("span is null");
            return;
        }

        HttpURI uri = getURI();
        tags[HTTP_HOST] = uri.getHost();
        tags[HTTP_URL] = uri.getPathQuery();
        tags[HTTP_PATH] = uri.getPath();
        tags[HTTP_REQUEST_SIZE] = getContentLength().to!string();
        tags[HTTP_METHOD] = getMethod();

        if(_span !is null) {
            _span.start();
            getFields().put("b3", _span.defaultId());
        }
    }    
    
    void endTraceSpan(int status, string message) {
        
        if(!isTracingEnabled()) return;
        if(_span !is null) {
            tags[HTTP_STATUS_CODE] = to!string(status);
            // tags[HTTP_RESPONSE_SIZE] = to!string(response.getContentLength());

            traceSpanAfter(_span , tags, message);

            httpSender().sendSpans(_span);
        }
    }
} else {
    private bool _isTracingEnabled = false;
}

}
