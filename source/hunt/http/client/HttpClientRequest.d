module hunt.http.client.HttpClientRequest;

import hunt.http.client.CookieStore;
import hunt.http.client.InMemoryCookieStore;

import hunt.http.AuthenticationScheme;
import hunt.http.Cookie;
import hunt.http.HttpBody;
import hunt.http.HttpHeader;
import hunt.http.HttpFields;
import hunt.http.HttpMetaData;
import hunt.http.HttpMethod;
import hunt.http.HttpRequest;
import hunt.http.HttpScheme;
import hunt.http.HttpVersion;

import hunt.collection.ByteBuffer;
import hunt.collection.HeapByteBuffer;
import hunt.collection.BufferUtils;
import hunt.Exceptions;
import hunt.logging.ConsoleLogger;
import hunt.net.KeyCertOptions;
import hunt.net.PemKeyCertOptions;
import hunt.net.util.HttpURI;

import std.array;
import std.algorithm;
import std.conv;
import std.file;
import std.path;
import std.string;

version(WITH_HUNT_TRACE) {
    import hunt.trace.Constrants;
    import hunt.trace.Endpoint;
    import hunt.trace.Span;
    import hunt.trace.Tracer;
    import hunt.trace.HttpSender;
}

/**
 * 
 */
class HttpClientRequest : HttpRequest {

	private Cookie[] _cookies;
    private bool _isCookieStoreEnabled = true;

    // SSL/TLS settings
    KeyCertOptions _keyCertOptions;
    private bool _isCertificateAuth;

	this(string method, string uri) {
		HttpFields fields = new HttpFields();
		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, fields);
	}

	this(string method, string uri, HttpBody content) {
		HttpFields fields = new HttpFields();
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());

		super(method, new HttpURI(uri), HttpVersion.HTTP_1_1, fields,  
			content is null ? 0 : content.contentLength());
        this.setBody(content);
	}
	
	this(string method, HttpURI uri, HttpFields fields, HttpBody content) {
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());

		super(method, uri, HttpVersion.HTTP_1_1, fields, 
			content is null ? 0 : content.contentLength());
        this.setBody(content);
	}
	
	this(string method, HttpURI uri, HttpVersion ver, HttpFields fields, HttpBody content) {
		if(content !is null)
			fields.add(HttpHeader.CONTENT_TYPE, content.contentType());
			
		super(method, uri, ver, fields,  
			content is null ? 0 : content.contentLength());
        this.setBody(content);
	}

	this(HttpRequest request) {
		super(request);
	}

    bool isCookieStoreEnabled() {
        return _isCookieStoreEnabled;
    }

    void isCookieStoreEnabled(bool flag) {
        _isCookieStoreEnabled = flag;
    }

    bool isTracingEnabled() {
        return _isTracingEnabled;
    }

    void isTracingEnabled(bool flag) {
        _isTracingEnabled = flag;
    }

    void isCertificateAuth(bool flag) {
        _isCertificateAuth = flag;
    }

    bool isCertificateAuth() {
        return _isCertificateAuth;
    }

    KeyCertOptions getKeyCertOptions() {
        return _keyCertOptions;
    }

    void setKeyCertOptions(KeyCertOptions options) {
        _keyCertOptions = options;
    }

	RequestBuilder newBuilder() {
		return new RequestBuilder(this);
	}

version(WITH_HUNT_TRACE) {
    private bool _isTracingEnabled = true;
    private Span _span;
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

    /**
     * 
     */
    final static class Builder {

        private HttpURI _url;
        private string _method;
        private HttpFields _headers;
        private HttpBody _requestBody;

        // SSL/TLS settings
        private bool _isCertificateAuth = false;
        private string _tlsCaFile;
        private string _tlsCaPassworld;
        private string _tlsCertificate;
        private string _tlsPrivateKey;
        private string _tlsCertPassword;
        private string _tlsKeyPassword;


        /** A mutable map of tags, or an immutable empty map if we don't have any. */
        // Map<Class<?>, Object> tags = Collections.emptyMap();

        this() {
            this._method = "GET";
            this._headers = new HttpFields();
        }

        this(Request request) {
            this._url = request.getURI();
            this._method = request.getMethod();
            this._requestBody = request.getBody();
        //   this.tags = request.tags.isEmpty()
        //       ? Collections.emptyMap()
        //       : new LinkedHashMap<>(request.tags);
            this._headers = request.getFields();
        }

        Builder url(HttpURI url) {
            if (url is null) throw new NullPointerException("url is null");
            this._url = url;
            return this;
        }

        /**
         * Sets the URL target of this request.
         *
         * @throws IllegalArgumentException if {@code url} is not a valid HTTP or HTTPS URL. Avoid this
         * exception by calling {@link HttpURI#parse}; it returns null for invalid URLs.
         */
        Builder url(string httpUri) {
            if (httpUri is null) throw new NullPointerException("url is null");

            // Silently replace web socket URLs with HTTP URLs.
            if (httpUri.length >= 3 && icmp(httpUri[0..3], "ws:") == 0) {
                httpUri = "http:" ~ httpUri[3 .. $];
            } else if (httpUri.length >=4 && icmp(httpUri[0 .. 4], "wss:") == 0) {
                httpUri = "https:" ~ httpUri[4 .. $];
            }

            return url(new HttpURI(httpUri));
        }

        /**
         * Sets the header named {@code name} to {@code value}. If this request already has any headers
         * with that name, they are all replaced.
         */
        Builder header(string name, string value) {
            _headers.put(name, value);
            return this;
        }

        /**
         * Adds a header with {@code name} and {@code value}. Prefer this method for multiply-valued
         * headers like "Cookie".
         *
         * <p>Note that for some headers including {@code Content-Length} and {@code Content-Encoding},
         * OkHttp may replace {@code value} with a header derived from the request body.
         */
        Builder addHeader(string name, string value) {
            _headers.add(name, value);
            return this;
        }

        /** Removes all headers named {@code name} on this builder. */
        Builder removeHeader(string name) {
            _headers.remove(name);
            return this;
        }

        /** Removes all headers on this builder and adds {@code headers}. */
        Builder headers(HttpFields headers) {
            _headers = headers;
            return this;
        }

        // Enable header authorization
        Builder authorization(AuthenticationScheme scheme, string token) {
            header("Authorization", scheme ~ " " ~ token);
            return this;
        }

        // Enable certificate authorization
        // https://github.com/Hakky54/mutual-tls-ssl
        Builder mutualTls(string certificate, string privateKey, string certPassword="", string keyPassword="") {
            _isCertificateAuth = true;
            _tlsCertificate = certificate;
            _tlsPrivateKey = privateKey;
            _tlsCertPassword = certPassword;
            _tlsKeyPassword = keyPassword;
            return this;
        }

        // Certificate Authority (CA) certificate
        Builder caCert(string caFile, string caPassword) {
            _tlsCaFile = caFile;
            _tlsCaPassworld = caPassword;
            return this;
        }
          

        /**
         * Sets this request's {@code Cache-Control} header, replacing any cache control headers already
         * present. If {@code cacheControl} doesn't define any directives, this clears this request's
         * cache-control headers.
         */
        // Builder cacheControl(CacheControl cacheControl) {
        //   string value = cacheControl.toString();
        //   if (value.isEmpty()) return removeHeader("Cache-Control");
        //   return header("Cache-Control", value);
        // }

        Builder get() {
            return method("GET", null);
        }

        Builder head() {
            return method("HEAD", null);
        }

        Builder post(HttpBody requestBody) {
            return method("POST", requestBody);
        }

        Builder del(HttpBody requestBody) {
            return method("DELETE", requestBody);
        }

        Builder del() {
            return method("DELETE", null);
        }

        Builder put(HttpBody requestBody) {
            return method("PUT", requestBody);
        }

        Builder patch(HttpBody requestBody) {
            return method("PATCH", requestBody);
        }

        Builder method(string method, HttpBody requestBody) {
            if (method.empty) throw new NullPointerException("method is empty");

            if (requestBody !is null && !HttpMethod.permitsRequestBody(method)) {
                throw new IllegalArgumentException("method " ~ method ~ " must not have a request body.");
            }
            if (requestBody is null && HttpMethod.requiresRequestBody(method)) {
                throw new IllegalArgumentException("method " ~ method ~ " must have a request body.");
            }
            this._method = method;
            this._requestBody = requestBody;
            return this;
        }

        /**
         * Set the cookies.
         *
         * @param cookies The cookies.
         * @return Builder
         */
        Builder cookies(Cookie[] cookies) {
            _headers.put(HttpHeader.COOKIE, generateCookies(cookies));
            return this;
        }
		
        Builder cookieStoreEnabled(bool flag) {
            _isCookieStoreEnabled = flag;
            return this;
        }
        private bool _isCookieStoreEnabled = true;

        // Trace
        Builder enableTracing(bool flag) {
            _isTracingEnabled = flag;
            return this;
        }
        
version(WITH_HUNT_TRACE) {
    
        Builder withTracer(Tracer t) {
            _tracer = t;
            return this;
        }

        Builder localServiceName(string name) {
            _localServiceName = name;
            return this;
        }

        private Tracer _tracer;
        private string _localServiceName;

        private bool _isTracingEnabled = true;
} else {
        private bool _isTracingEnabled = false;
}

        /** Attaches {@code tag} to the request using {@code Object.class} as a key. */
        // Builder tag(Object tag) {
        //   return tag(Object.class, tag);
        // }

        /**
         * Attaches {@code tag} to the request using {@code type} as a key. Tags can be read from a
         * request using {@link Request#tag}. Use null to remove any existing tag assigned for {@code
         * type}.
         *
         * <p>Use this API to attach timing, debugging, or other application data to a request so that
         * you may read it in interceptors, event listeners, or callbacks.
         */
        // <T> Builder tag(Class<? super T> type, T tag) {
        //   if (type is null) throw new NullPointerException("type is null");

        //   if (tag is null) {
        //     tags.remove(type);
        //   } else {
        //     if (tags.isEmpty()) tags = new LinkedHashMap<>();
        //     tags.put(type, type.cast(tag));
        //   }

        //   return this;
        // }

        HttpClientRequest build() {
            if (_url is null) throw new IllegalStateException("url is null");

            string basePath = dirName(thisExePath);

			HttpClientRequest request = new HttpClientRequest(_method, _url, _headers, _requestBody);
			request._isCookieStoreEnabled = _isCookieStoreEnabled;
            request._isTracingEnabled = _isTracingEnabled;
            version(WITH_HUNT_TRACE) {
                if(_isTracingEnabled) {
                    string spanName = _url.getPath();
                    Span span;
                    if(_tracer is null) {
                        _tracer = new Tracer(spanName);
                        span = _tracer.root; 
                    } else {
                        span = _tracer.addSpan(spanName);
                    }

                    span.initializeLocalEndpoint(_localServiceName);

                    // EndPoint remoteEndpoint = new EndPoint();
                    // remoteEndpoint.port = _url.getPort();
                    
                    // try {
                    //     auto addresses = getAddress(_url.getHost());
                    //     foreach (address; addresses) {
                    //         // writefln("  IP: %s", address.toAddrString());
                    //         string ip = address.toAddrString();
                    //         if(ip.startsWith("::")) {
                    //             remoteEndpoint.ipv6 = ip;
                    //         } else {
                    //             remoteEndpoint.ipv4 = ip;
                    //         }
                    //     }
                    // } catch(Exception ex) {
                    //     warning(ex.msg);
                    // }

                    // span.remoteEndpoint = remoteEndpoint;

                    request.tracer = _tracer;
                    request._span = span;
                }
            }

            if(!_tlsCertificate.empty()) {
                PemKeyCertOptions options = new PemKeyCertOptions(buildPath(basePath, _tlsCertificate),
                    buildPath(basePath, _tlsPrivateKey), _tlsCertPassword, _tlsKeyPassword);
                
                if(!_tlsCaFile.empty()) {
                    options.setCaFile(buildPath(basePath, _tlsCaFile));
                    options.setCaPassword(_tlsCaPassworld);
                }
                request.setKeyCertOptions(options);
                request.isCertificateAuth = _isCertificateAuth;
            }

            return request;
        }
    }    	
}


alias Request = HttpClientRequest;

alias RequestBuilder = HttpClientRequest.Builder;