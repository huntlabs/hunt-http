module hunt.http.server.Http2ServerRequestHandler;

import hunt.http.server.HttpServerResponse;
import hunt.http.server.Http2ServerConnection;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.AbstractHttp2OutputStream;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Stream;

import hunt.http.codec.http.stream.DataFrameHandler;

import hunt.http.HttpFields;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpMethod;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpStatus;
import hunt.http.HttpVersion;
import hunt.http.Version;

import hunt.Exceptions;
import hunt.util.Common;
import hunt.text.Common;

import hunt.logging;
import std.conv;
import std.string;

alias StreamListener = hunt.http.codec.http.stream.Stream.Stream.Listener;

/**
*/
class Http2ServerRequestHandler : ServerSessionListener.Adapter {

    private ServerHttpHandler serverHttpHandler;
    Http2ServerConnection connection;

    this(ServerHttpHandler serverHttpHandler) {
        this.serverHttpHandler = serverHttpHandler;
    }

    override
    void onClose(Session session, GoAwayFrame frame) {
        warningf("Server received the GoAwayFrame -> %s", frame.toString());
        connection.close();
    }

    override
    void onFailure(Session session, Exception failure) {
        errorf("Server failure: " ~ session.toString(), failure);
        // Optional.ofNullable(connection).ifPresent(IO::close);
        if(connection !is null)
            connection.close();
    }

    override
    void onReset(Session session, ResetFrame frame) {
        warningf("Server received ResetFrame %s", frame.toString());
        // Optional.ofNullable(connection).ifPresent(IO::close);

        if(connection !is null)
            connection.close();
    }

    override
    StreamListener onNewStream(Stream stream, HeadersFrame headersFrame) {
        if (!headersFrame.getMetaData().isRequest()) {
            throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received meta data that is not request type");
        }

        version(HUNT_DEBUG) {
            tracef("Server received stream: %s, %s", stream.getId(), headersFrame.toString());
        }

        HttpRequest request = cast(HttpRequest) headersFrame.getMetaData();
        HttpResponse response = new HttpServerResponse();
        ServerHttp2OutputStream output = new ServerHttp2OutputStream(response, stream);

        string expectedValue = request.getFields().get(HttpHeader.EXPECT);
        if ("100-continue".equalsIgnoreCase(expectedValue)) {
            bool skipNext = serverHttpHandler.accept100Continue(request, response, output, connection);
            if (!skipNext) {
                HttpResponse continue100 = new HttpResponse(HttpVersion.HTTP_1_1,
                        HttpStatus.CONTINUE_100, HttpStatus.Code.CONTINUE.getMessage(),
                        new HttpFields(), -1);
                output.writeFrame(new HeadersFrame(stream.getId(), continue100, null, false));
            }
        } else {
            serverHttpHandler.headerComplete(request, response, output, connection);
            if (headersFrame.isEndStream()) {
                serverHttpHandler.messageComplete(request, response, output, connection);
            }
        }

        

        return new class StreamListener.Adapter {
            override
            void onHeaders(Stream stream, HeadersFrame trailerFrame) {
                version(HUNT_DEBUG) {
                    tracef("Server received trailer frame: %s, %s", stream.toString(), trailerFrame);
                }

                if (trailerFrame.isEndStream()) {
                    request.setTrailerSupplier(() => trailerFrame.getMetaData().getFields());
                    serverHttpHandler.contentComplete(request, response, output, connection);
                    serverHttpHandler.messageComplete(request, response, output, connection);
                } else {
                    throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received illegal meta data");
                }
            }

            override
            void onData(Stream stream, DataFrame dataFrame, Callback callback) {
                DataFrameHandler.handleDataFrame(dataFrame, callback, request, response, output, connection, serverHttpHandler);
            }

            override
            void onReset(Stream stream, ResetFrame resetFrame) {
                int errorCode = resetFrame.getError();
                string reason; 
                int status = HttpStatus.INTERNAL_SERVER_ERROR_500;
                if (isValidErrorCode(errorCode)) {
                    switch (cast(ErrorCode)errorCode) {
                        case ErrorCode.PROTOCOL_ERROR:
                            status = HttpStatus.BAD_REQUEST_400;
                            break;
                        default:
                            status = HttpStatus.INTERNAL_SERVER_ERROR_500;
                            break;
                    }
                    reason =  (cast(ErrorCode)errorCode).to!string().toLower();
                }
                else
                    reason =  "error=" ~ resetFrame.getError().to!string();

                serverHttpHandler.badMessage(status, reason, request, response, output, connection);
            }
        };
    }

    static class ServerHttp2OutputStream : AbstractHttp2OutputStream {

        private Stream stream;

        this(HttpMetaData info, Stream stream) {
            super(info, false);
            this.stream = stream;
            info.getFields().put(HttpHeader.X_POWERED_BY, X_POWERED_BY_VALUE);
            info.getFields().put(HttpHeader.SERVER, SERVER_VALUE);
        }

        override
        protected Stream getStream() {
            return stream;
        }
    }

}
