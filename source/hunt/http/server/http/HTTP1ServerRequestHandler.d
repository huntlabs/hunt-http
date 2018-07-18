module hunt.http.server.http.HTTP1ServerRequestHandler;


import hunt.http.server.http.HTTP1ServerConnection;
import hunt.http.server.http.HTTP2ServerHandler;
import hunt.http.server.http.HTTPServerRequest;
import hunt.http.server.http.HTTPServerResponse;
import hunt.http.server.http.ServerHTTPHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;

import hunt.container.ByteBuffer;
import hunt.util.string;

import kiss.logger;

alias RequestHandler = HttpParser.RequestHandler;
alias HTTP1ServerResponseOutputStream = HTTP1ServerConnection.HTTP1ServerResponseOutputStream;

/**
*/
class HTTP1ServerRequestHandler : RequestHandler {


    package(hunt.http.server.http) MetaData.Request request;
    package(hunt.http.server.http) MetaData.Response response;
    package(hunt.http.server.http) HTTP1ServerConnection connection;
    package(hunt.http.server.http) HTTP1ServerResponseOutputStream outputStream;
    package(hunt.http.server.http) ServerHTTPHandler serverHTTPHandler;
    package(hunt.http.server.http) HttpFields trailer;

    this(ServerHTTPHandler serverHTTPHandler) {
        this.serverHTTPHandler = serverHTTPHandler;
    }

    override
    bool startRequest(string method, string uri, HttpVersion ver) {
        version(HuntDebugMode) {
            tracef("server received the request line, %s, %s, %s", method, uri, ver);
        }

        request = new HTTPServerRequest(method, uri, ver);
        response = new HTTPServerResponse();
        outputStream = new HTTP1ServerResponseOutputStream(response, connection);

        return HttpMethod.PRI.isSame(method) && connection.directUpgradeHTTP2(request);
    }

    override
    void parsedHeader(HttpField field) {
        request.getFields().add(field);
    }

    override
    bool headerComplete() {
        if (HttpMethod.CONNECT.asString().equalsIgnoreCase(request.getMethod())) {
            return serverHTTPHandler.acceptHTTPTunnelConnection(request, response, outputStream, connection);
        } else {
            string expectedValue = request.getFields().get(HttpHeader.EXPECT);
            if ("100-continue".equalsIgnoreCase(expectedValue)) {
                bool skipNext = serverHTTPHandler.accept100Continue(request, response, outputStream, connection);
                if (skipNext) {
                    return true;
                } else {
                    connection.response100Continue();
                    return serverHTTPHandler.headerComplete(request, response, outputStream, connection);
                }
            } else {
                return serverHTTPHandler.headerComplete(request, response, outputStream, connection);
            }
        }
    }

    override
    bool content(ByteBuffer item) {
        return serverHTTPHandler.content(item, request, response, outputStream, connection);
    }

    override
    bool contentComplete() {
        return serverHTTPHandler.contentComplete(request, response, outputStream, connection);
    }

    override
    void parsedTrailer(HttpField field) {
        if (trailer is null) {
            trailer = new HttpFields();
            request.setTrailerSupplier(() => trailer);
        }
        trailer.add(field);
    }

    override
    bool messageComplete() {
        try {
            if (connection.getUpgradeHTTP2Complete() || connection.getUpgradeWebSocketComplete()) {
                return true;
            } else {
                bool success = connection.upgradeProtocol(request, response, outputStream, connection);
                return success || serverHTTPHandler.messageComplete(request, response, outputStream, connection);
            }
        } finally {
            connection.getParser().reset();
        }
    }

    override
    void badMessage(int status, string reason) {
        serverHTTPHandler.badMessage(status, reason, request, response, outputStream, connection);
    }


    void badMessage(BadMessageException failure)
    {
        badMessage(failure.getCode(), failure.getReason());
    }


    override
    void earlyEOF() {
        serverHTTPHandler.earlyEOF(request, response, outputStream, connection);
    }

    override
    int getHeaderCacheSize() {
        return 1024;
    }

}
