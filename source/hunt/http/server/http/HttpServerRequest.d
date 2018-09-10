module hunt.http.server.http.HttpServerRequest;

import hunt.http.codec.http.model;

class HttpServerRequest : MetaData.Request {

    this(string method, string uri, HttpVersion ver) {
        super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
    }
}
