module hunt.http.server.HttpServerRequest;

import hunt.http.codec.http.model;

class HttpServerRequest : HttpRequest {

    this(string method, string uri, HttpVersion ver) {
        super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
    }
}
