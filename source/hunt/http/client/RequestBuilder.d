module hunt.http.client.RequestBuilder;

import hunt.http.client.HttpClientRequest;
import hunt.http.client.RequestBody;

import hunt.net.util.HttpURI;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.http.model.HttpFields;
import hunt.http.codec.http.model.HttpMethod;
import hunt.http.codec.http.model.HttpScheme;

import hunt.Exceptions;

import std.array;
import std.algorithm;
import std.string;

version(WITH_HUNT_TRACE) {
    import hunt.trace.Constrants;
    import hunt.trace.Endpoint;
    import hunt.trace.Span;
    import hunt.trace.Tracer;
    import hunt.trace.HttpSender;
}

/**
*/
class RequestBuilder {

        HttpURI _url;
        string _method;
        HttpFields _headers;
        RequestBody _requestBody;

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

        RequestBuilder url(HttpURI url) {
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
        RequestBuilder url(string httpUri) {
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
        RequestBuilder header(string name, string value) {
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
        RequestBuilder addHeader(string name, string value) {
            _headers.add(name, value);
            return this;
        }

        /** Removes all headers named {@code name} on this builder. */
        RequestBuilder removeHeader(string name) {
            _headers.remove(name);
            return this;
        }

        /** Removes all headers on this builder and adds {@code headers}. */
        RequestBuilder headers(HttpFields headers) {
            _headers = headers;
            return this;
        }

        /**
         * Sets this request's {@code Cache-Control} header, replacing any cache control headers already
         * present. If {@code cacheControl} doesn't define any directives, this clears this request's
         * cache-control headers.
         */
        // RequestBuilder cacheControl(CacheControl cacheControl) {
        //   string value = cacheControl.toString();
        //   if (value.isEmpty()) return removeHeader("Cache-Control");
        //   return header("Cache-Control", value);
        // }

        RequestBuilder get() {
            return method("GET", null);
        }

        RequestBuilder head() {
            return method("HEAD", null);
        }

        RequestBuilder post(RequestBody requestBody) {
            return method("POST", requestBody);
        }

        RequestBuilder del(RequestBody requestBody) {
            return method("DELETE", requestBody);
        }

        RequestBuilder del() {
            return method("DELETE", null);
        }

        RequestBuilder put(RequestBody requestBody) {
            return method("PUT", requestBody);
        }

        RequestBuilder patch(RequestBody requestBody) {
            return method("PATCH", requestBody);
        }

        RequestBuilder method(string method, RequestBody requestBody) {
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

        // Trace
        RequestBuilder enableTracing(bool flag) {
            _isTracingEnabled = flag;
            return this;
        }
        
version(WITH_HUNT_TRACE) {
    
        RequestBuilder withTracer(Tracer t) {
            _tracer = t;
            return this;
        }

        RequestBuilder localServiceName(string name) {
            _localServiceName = name;
            return this;
        }

        private Tracer _tracer;
        private string _localServiceName;

        private bool _isTracingEnabled = true;
} else {
        private bool _isTracingEnabled = false;
}
        Request build() {
            if (_url is null) throw new IllegalStateException("url is null");
            HttpClientRequest request = new Request(_method, _url, _headers, _requestBody);
            request.isTracingEnabled = _isTracingEnabled;

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

                    request._tracer = _tracer;
                    request._span = span;
                }
            }

            return request;
        }
}
