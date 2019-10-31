module hunt.http.client.HttpClientRequest;

import hunt.http.client.CookieStore;
import hunt.http.client.InMemoryCookieStore;
import hunt.http.client.RequestBody;

import hunt.http.AuthenticationScheme;
import hunt.http.Cookie;
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
import hunt.net.util.HttpURI;

import std.array;
import std.algorithm;
import std.string;


/**
*/
class HttpClientRequest : HttpRequest {

	private RequestBody _body;
	private Cookie[] _cookies;
    private bool _cookieStoreEnabled = true;

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

    bool isCookieStoreEnabled() {
        return _cookieStoreEnabled;
    }

	RequestBuilder newBuilder() {
		return new RequestBuilder(this);
	}
	

    /**
    */
    final static class Builder {

        private HttpURI _url;
        private string _method;
        private HttpFields _headers;
        private RequestBody _requestBody;
        private bool _cookieStoreEnabled = true;

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

        Builder authorization(AuthenticationScheme scheme, string token) {
            header("Authorization", scheme ~ " " ~ token);
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

        Builder post(RequestBody requestBody) {
            return method("POST", requestBody);
        }

        Builder del(RequestBody requestBody) {
            return method("DELETE", requestBody);
        }

        Builder del() {
            return method("DELETE", null);
        }

        Builder put(RequestBody requestBody) {
            return method("PUT", requestBody);
        }

        Builder patch(RequestBody requestBody) {
            return method("PATCH", requestBody);
        }

        Builder method(string method, RequestBody requestBody) {
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
		
        Builder disableCookieStore() {
            _cookieStoreEnabled = false;
            return this;
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

			HttpClientRequest request = new Request(_method, _url, _headers, _requestBody);
			request._cookieStoreEnabled = _cookieStoreEnabled;
            return request;
        }
    }    	
}


alias Request = HttpClientRequest;

alias RequestBuilder = HttpClientRequest.Builder;