module hunt.http.HttpMetaData;

import hunt.http.HttpBody;
import hunt.http.HttpHeader;
import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;

import hunt.collection;
import hunt.Functions;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.net.util.HttpURI;
import hunt.text.Common;
import hunt.text.StringBuilder;
import hunt.util.Common;

import std.ascii;
import std.conv;
import std.format;
import std.range;

deprecated("Using HttpMetaData instead.")
alias MetaData = HttpMetaData;

// from org.apache.hc.core5.http;
// HttpMessage : MessageHeaders
// 

/**
 * 
 */
class HttpMetaData : Iterable!HttpField {

    enum string ConntentTypeHeader = HttpHeader.CONTENT_TYPE.toString();
    enum string ConntentLengthHeader = HttpHeader.CONTENT_TYPE.toString();
    
    private HttpVersion _httpVersion;
    private HttpFields _fields;
	private HttpBody _body;
    private long _contentLength;
    protected string _contentType;
    private Supplier!HttpFields _trailers;

    this(HttpVersion ver, HttpFields fields) {
        this(ver, fields, long.min);
    }

    this(HttpVersion ver, HttpFields fields, long contentLength) {
        version(HUNT_HTTP_DEBUG) {
            if(contentLength>0) {
                tracef("version: %s", ver.toString());
                tracef("contentLength: %d", contentLength);
                if(fields !is null) {
                    tracef(fields.toString());
                }
            }
        }
        // assert(fields !is null);
        _httpVersion = ver;
        _fields = fields;
        _contentLength = contentLength;
    }

    protected void recycle() {
        _httpVersion = HttpVersion.Null;
        if (_fields !is null)
            _fields.clear();
        _contentLength = long.min;
    }

    bool isRequest() {
        return false;
    }

    bool isResponse() {
        return false;
    }

	bool haveBody() {
		return _body !is null;
	}
    
    /**
     * @deprecated use {@link #getHttpVersion()} instead
     */
    // deprecated("")
    // HttpVersion getVersion() {
    //     return getHttpVersion();
    // }

    /**
     * @return the HTTP version of this HttpMetaData object
     */
    HttpVersion getHttpVersion() {
        return _httpVersion;
    }

    /**
     * @param httpVersion the HTTP version to set
     */
    void setHttpVersion(HttpVersion httpVersion) {
        _httpVersion = httpVersion;
    }

    /**
     * @return the HTTP fields of this HttpMetaData object
     */
    HttpFields getFields() {
        return _fields;
    }

    Supplier!HttpFields getTrailerSupplier() {
        return _trailers;
    }

    void setTrailerSupplier(Supplier!HttpFields trailers) {
        _trailers = trailers;
    }

	/**
	 * Returns a non-null value if this response was passed to {@link Callback#onResponse} or returned
	 * from {@link Call#execute()}. Response bodies must be {@linkplain ResponseBody closed} and may
	 * be consumed only once.
	 *
	 * <p>This always returns null on responses returned from {@link #cacheResponse}, {@link
	 * #networkResponse}, and {@link #priorResponse()}.
	 */
	HttpBody getBody() {		
		return _body;
	}	

	HttpMetaData setBody(HttpBody b) {
        if(b !is null) {
            HttpFields fields = getFields();
            if(!fields.contains(HttpHeader.CONTENT_TYPE)) {
                fields.put(HttpHeader.CONTENT_TYPE, b.contentType);
            } else {
                version(HUNT_HTTP_DEBUG) {
                    string existedType = fields.get(HttpHeader.CONTENT_TYPE);
                    string newType = b.contentType();
                    if(existedType != newType) {
                        warningf("content-type collision, old: %s, new: %s", existedType, newType);
                    }

                    if(fields.contains(HttpHeader.CONTENT_LENGTH)) {
                        auto len = fields.get(HttpHeader.CONTENT_LENGTH);
                        tracef("content-type: %s, content-length: %s", existedType, len);
                    } else {
                        tracef("content-type: %s", existedType);
                    }
                }
            }

            fields.put(HttpHeader.CONTENT_LENGTH, b.contentLength.to!string());
        }
		_body = b;

        return this;
	}	

    /**
     * @return the content length if available, otherwise {@link Long#MIN_VALUE}
     */
    long getContentLength() {
        if (_contentLength == long.min || _contentLength == -1) {
            if (_fields !is null) {
                HttpField field = _fields.getField(HttpHeader.CONTENT_LENGTH);
                _contentLength = field is null ? -1 : field.getLongValue();
            }
        }
        version(HUNT_HTTP_DEBUG_MORE) tracef("contentLength=%d", _contentLength);
        return _contentLength;
    }

    string getContentType() {
        if (_contentType.empty()) {
            if (_fields !is null) {
                HttpField field = _fields.getField(HttpHeader.CONTENT_TYPE);
                _contentType = field is null ? "" : field.getValue();
            }
        }
        return _contentType;
    }

    string[] headers(string name) {
        HttpFields fs = getFields();
        if(fs !is null)
            return fs.getValuesList(name);
        else
            return null;
    }

    string header(string name) {
        return getFields().get(name);
    }

    string header(HttpHeader h) {
        return getFields().get(h);
    }

    // string header(string name, string defaultValue) {
    //     HttpFields fs = getFields();
    //     string result = fs.get(name);
    //     return result.empty ? defaultValue : result;
    // }

    HttpFields headers() {
        return getFields();
    }    

    /**
     * @return an iterator over the HTTP fields
     * @see #getFields()
     */
    InputRange!HttpField iterator() {
        return _fields is null ? inputRangeObject(new HttpField[0]) : _fields.iterator();
    }


    int opApply(scope int delegate(ref HttpField) dg) {
        int result = 0;
        foreach(HttpField v; _fields)
        {
            result = dg(v);
            if(result != 0) return result;
        }
        return result;
    }

    override string toString() {
        StringBuilder sb = new StringBuilder();
        foreach (HttpField field ; _fields)
            sb.append(field.toString()).append(std.ascii.newline);
        return sb.toString();
    }

    
    alias withBody = setBody;

}

