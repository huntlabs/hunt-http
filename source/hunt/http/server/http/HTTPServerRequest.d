module hunt.http.server.http.HTTPServerRequest;

import hunt.http.codec.http.model;

class HTTPServerRequest : MetaData.Request {

    this(string method, string uri, HttpVersion ver) {
        super(method, new HttpURI(HttpMethod.fromString(method) == HttpMethod.CONNECT ? "http://" ~ uri : uri), ver, new HttpFields());
    }
}
