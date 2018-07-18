module hunt.http.server.http.HTTP2ServerRequestHandler;

import hunt.http.server.http.HTTPServerResponse;
import hunt.http.server.http.HTTP2ServerConnection;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.server.http.ServerSessionListener;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.AbstractHTTP2OutputStream;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Stream;

import hunt.http.codec.http.stream.DataFrameHandler;
import hunt.http.environment;

import hunt.util.exception;
import hunt.util.functional;
import hunt.util.string;

import kiss.logger;
import std.conv;
import std.string;

alias StreamListener = hunt.http.codec.http.stream.Stream.Stream.Listener;

/**
*/
class HTTP2ServerRequestHandler : ServerSessionListener.Adapter {

    private ServerHTTPHandler serverHTTPHandler;
    HTTP2ServerConnection connection;

    this(ServerHTTPHandler serverHTTPHandler) {
        this.serverHTTPHandler = serverHTTPHandler;
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

        version(HuntDebugMode) {
            tracef("Server received stream: %s, %s", stream.getId(), headersFrame.toString());
        }

        MetaData.Request request = cast(MetaData.Request) headersFrame.getMetaData();
        MetaData.Response response = new HTTPServerResponse();
        ServerHttp2OutputStream output = new ServerHttp2OutputStream(response, stream);

        string expectedValue = request.getFields().get(HttpHeader.EXPECT);
        if ("100-continue".equalsIgnoreCase(expectedValue)) {
            bool skipNext = serverHTTPHandler.accept100Continue(request, response, output, connection);
            if (!skipNext) {
                MetaData.Response continue100 = new MetaData.Response(HttpVersion.HTTP_1_1,
                        HttpStatus.CONTINUE_100, HttpStatus.Code.CONTINUE.getMessage(),
                        new HttpFields(), -1);
                output.writeFrame(new HeadersFrame(stream.getId(), continue100, null, false));
            }
        } else {
            serverHTTPHandler.headerComplete(request, response, output, connection);
            if (headersFrame.isEndStream()) {
                serverHTTPHandler.messageComplete(request, response, output, connection);
            }
        }

        

        return new class StreamListener.Adapter {
            override
            void onHeaders(Stream stream, HeadersFrame trailerFrame) {
                version(HuntDebugMode) {
                    tracef("Server received trailer frame: %s, %s", stream.toString(), trailerFrame);
                }

                if (trailerFrame.isEndStream()) {
                    request.setTrailerSupplier(() => trailerFrame.getMetaData().getFields());
                    serverHTTPHandler.contentComplete(request, response, output, connection);
                    serverHTTPHandler.messageComplete(request, response, output, connection);
                } else {
                    throw new IllegalArgumentException("the stream " ~ stream.getId().to!string() ~ " received illegal meta data");
                }
            }

            override
            void onData(Stream stream, DataFrame dataFrame, Callback callback) {
                DataFrameHandler.handleDataFrame(dataFrame, callback, request, response, output, connection, serverHTTPHandler);
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

                serverHTTPHandler.badMessage(status, reason, request, response, output, connection);
            }
        };
    }

    static class ServerHttp2OutputStream : AbstractHTTP2OutputStream {

        enum string X_POWERED_BY_VALUE = "Hunt " ~ Version;
        enum string SERVER_VALUE = "Hunt " ~ Version;

        private Stream stream;

        this(MetaData info, Stream stream) {
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
