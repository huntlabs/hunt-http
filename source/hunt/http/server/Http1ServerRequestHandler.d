module hunt.http.server.Http1ServerRequestHandler;

import hunt.http.server.Http1ServerConnection;
import hunt.http.server.HttpServerOptions;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.ServerHttpHandler;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;

import hunt.http.HttpField;
import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMethod;
import hunt.http.HttpResponse;
import hunt.http.HttpVersion;

import hunt.io.ByteBuffer;
import hunt.text.Common;

import hunt.logging;
import std.string : icmp;

// alias RequestHandler = HttpParser.RequestHandler;


/**
 * 
 */
class Http1ServerRequestHandler : HttpRequestParsingHandler {
    package HttpServerRequest request;
    package HttpServerResponse response;
    package Http1ServerConnection connection;
    package Http1ServerResponseOutputStream outputStream;
    package ServerHttpHandler serverHttpHandler;
    package HttpFields trailer;
    private HttpServerOptions _options;

    this(ServerHttpHandler serverHttpHandler, HttpServerOptions options) {
        this.serverHttpHandler = serverHttpHandler;
        _options = options;
    }

    override bool startRequest(string method, string uri, HttpVersion ver) {
        version (HUNT_HTTP_DEBUG) {
            tracef("server received the request line, %s, %s, %s", method, uri, ver);
        }

        request = new HttpServerRequest(method, uri, ver, _options);
        response = new HttpServerResponse();
        outputStream = new Http1ServerResponseOutputStream(response, connection);

        return HttpMethod.PRI.isSame(method) && connection.directUpgradeHttp2(request);
    }

    override void parsedHeader(HttpField field) {
        request.getFields().add(field);
    }

    override bool headerComplete() {
        if (HttpMethod.CONNECT.asString().equalsIgnoreCase(request.getMethod())) {
            return serverHttpHandler.acceptHttpTunnelConnection(request,
                    response, outputStream, connection);
        } else {
            string expectedValue = request.getFields().get(HttpHeader.EXPECT);
            if ("100-continue".equalsIgnoreCase(expectedValue)) {
                bool skipNext = serverHttpHandler.accept100Continue(request,
                        response, outputStream, connection);
                if (skipNext) {
                    return true;
                } else {
                    connection.response100Continue();
                    return serverHttpHandler.headerComplete(request, response,
                            outputStream, connection);
                }
            } else {
                return serverHttpHandler.headerComplete(request, response,
                        outputStream, connection);
            }
        }
    }

    override bool content(ByteBuffer item) {
        return serverHttpHandler.content(item, request, response, outputStream, connection);
    }

    override bool contentComplete() {
        assert(request !is null, "Execute startRequest first");
        return serverHttpHandler.contentComplete(request, response, outputStream, connection);
    }

    override void parsedTrailer(HttpField field) {
        if (trailer is null) {
            trailer = new HttpFields();
            request.setTrailerSupplier(() => trailer);
        }
        trailer.add(field);
    }

    override bool messageComplete() {
        try {
            if (connection.getUpgradeHttp2Complete() || connection.getUpgradeWebSocketComplete()) {
                return true;
            } else {
                bool success = connection.upgradeProtocol(request, response,
                        outputStream, connection);
                return success || serverHttpHandler.messageComplete(request,
                        response, outputStream, connection);
            }
        } catch (Exception ex) {
            error("Upgrade failed: ", ex.msg);
            return true;
        } finally {
            connection.getParser().reset();
        }
    }

    override void badMessage(int status, string reason) {
        if(response is null) {
            response = new HttpServerResponse(status, reason);
            outputStream = new Http1ServerResponseOutputStream(response, connection);
        }
        serverHttpHandler.badMessage(status, reason, request, response, outputStream, connection);
    }

    void badMessage(BadMessageException failure) {
        badMessage(failure.getCode(), failure.getReason());
    }

    override void earlyEOF() {
        serverHttpHandler.earlyEOF(request, response, outputStream, connection);
    }

    override int getHeaderCacheSize() {
        return 1024;
    }

}
