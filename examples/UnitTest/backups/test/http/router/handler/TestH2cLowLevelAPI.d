module test.http.router.handler;

import hunt.http.$;
import hunt.http.client.http2;
import hunt.http.codec.http.frame.DataFrame;
import hunt.http.codec.http.frame.HeadersFrame;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.Http2Configuration;
import hunt.http.codec.http.stream.HttpConnection;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Stream;
import hunt.http.server.HttpServer;
import hunt.http.server.ServerHttpHandler;
import hunt.http.server.ServerSessionListener;
import hunt.http.server.WebSocketHandler;
import hunt.util.functional;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;
import hunt.util.Assert;
import hunt.util.Test;

import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import hunt.container.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.Phaser;

import hunt.http.utils.io.BufferUtils.toBuffer;


/**
 * 
 */
public class TestH2cLowLevelAPI extends AbstractHttpHandlerTest {

    
    public void testLowLevelAPI() {
        Phaser phaser = new Phaser(2);
        HttpServer server = createServerLowLevelAPI();
        HttpClient client = createClientLowLevelClient(phaser);

        server.stop();
        client.stop();
    }

    public HttpServer createServerLowLevelAPI() {
        final Http2Configuration http2Configuration = new Http2Configuration();
        http2Configuration.setFlowControlStrategy("simple");
        http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);

        HttpServer server = new HttpServer(host, port, http2Configuration, new ServerSessionListener.Adapter() {

            override
            public Map<Integer, Integer> onPreface(Session session) {
                writeln("session preface: " ~ session);
                final Map<Integer, Integer> settings = new HashMap<>();
                settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
                settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
                return settings;
            }

            override
            public Stream.Listener onNewStream(Stream stream, HeadersFrame frame) {
                writeln("Server new stream, " ~ frame.getMetaData() ~ "|" ~ stream);

                MetaData metaData = frame.getMetaData();
                Assert.assertTrue(metaData.isRequest());
                final MetaData.Request request = (MetaData.Request) metaData;

                if (frame.isEndStream()) {
                    if (request.getURI().getPath().equals("/index")) {
                        MetaData.Response response = new MetaData.Response(HttpVersion.HTTP_2, 200, new HttpFields());
                        HeadersFrame headersFrame = new HeadersFrame(stream.getId(), response, null, true);
                        stream.headers(headersFrame, Callback.NOOP);
                    }
                }

                List!(ByteBuffer) contentList = new CopyOnWriteArrayList<>();

                return new Stream.Listener.Adapter() {

                    override
                    public void onHeaders(Stream stream, HeadersFrame frame) {
                        writeln("Server stream on headers " ~ frame.getMetaData() ~ "|" ~ stream);
                    }

                    override
                    public void onData(Stream stream, DataFrame frame, Callback callback) {
                        writeln("Server stream on data: " ~ frame);
                        contentList.add(frame.getData());
                        if (frame.isEndStream()) {
                            MetaData.Response response = new MetaData.Response(HttpVersion.HTTP_2, 200, new HttpFields());
                            HeadersFrame responseFrame = new HeadersFrame(stream.getId(), response, null, false);
                            writeln("Server session on data end: " ~ BufferUtils.toString(contentList));
                            stream.headers(responseFrame, new Callback() {
                                override
                                public void succeeded() {
                                    DataFrame dataFrame = new DataFrame(stream.getId(), BufferUtils.toBuffer("The server received data"), true);
                                    stream.data(dataFrame, Callback.NOOP);
                                }
                            });
                        }
                        callback.succeeded();
                    }
                };
            }

            override
            public void onAccept(Session session) {
                writeln("accept a new session " ~ session);
            }
        }, new ServerHttpHandlerAdapter(), new WebSocketHandler() {});
        server.start();
        return server;
    }

    public HttpClient createClientLowLevelClient(Phaser phaser) {
        final Http2Configuration http2Configuration = new Http2Configuration();
        http2Configuration.setFlowControlStrategy("simple");
        http2Configuration.getTcpConfiguration().setTimeout(60 * 1000);
        HttpClient client = new HttpClient(http2Configuration);

        FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
        client.connect(host, port, promise);

        HttpConnection connection = promise.get();
        Assert.assertThat(connection.getHttpVersion(), is(HttpVersion.HTTP_1_1));

        final Http1ClientConnection httpConnection = (Http1ClientConnection) connection;
        HttpClientRequest request = new HttpClientRequest("GET", "/index");

        Map<Integer, Integer> settings = new HashMap<>();
        settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
        settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
        SettingsFrame settingsFrame = new SettingsFrame(settings, false);

        FuturePromise<Http2ClientConnection> http2promise = new FuturePromise<>();
        FuturePromise<Stream> initStream = new FuturePromise<>();
        httpConnection.upgradeHttp2(request, settingsFrame, http2promise, initStream, new Stream.Listener.Adapter() {
            override
            public void onHeaders(Stream stream, HeadersFrame frame) {
                writeln($.string.replace("client stream {} received init headers: {}", stream.getId(), frame.getMetaData()));
            }

        }, new ClientHttp2SessionListener() {

            override
            public Map<Integer, Integer> onPreface(Session session) {
                writeln($.string.replace("client preface: {}", session));
                Map<Integer, Integer> settings = new HashMap<>();
                settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
                settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
                return settings;
            }

            override
            public void onFailure(Session session, Throwable failure) {
                failure.printStackTrace();
            }
        }, new ClientHttpHandler.Adapter());

        Http2ClientConnection clientConnection = http2promise.get();
        Assert.assertThat(clientConnection.getHttpVersion(), is(HttpVersion.HTTP_2));

        for (int i = 0; i < 1; i++) {
            testReq(phaser, clientConnection);
        }
        return client;
    }

    private void testReq(Phaser phaser, Http2ClientConnection clientConnection) throws InterruptedException, java.util.concurrent.ExecutionException {
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.ACCEPT, "text/html");
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        fields.put(HttpHeader.CONTENT_LENGTH, "28");
        MetaData.Request metaData = new MetaData.Request("POST", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port), "/data", HttpVersion.HTTP_2, fields);

        FuturePromise<Stream> streamPromise = new FuturePromise<>();
        clientConnection.getHttp2Session().newStream(new HeadersFrame(metaData, null, false), streamPromise,
                new Stream.Listener.Adapter() {

                    override
                    public void onHeaders(Stream stream, HeadersFrame frame) {
                        writeln($.string.replace("client received headers: {}", frame.getMetaData()));
                    }

                    override
                    public void onData(Stream stream, DataFrame frame, Callback callback) {
                        writeln($.string.replace("client received data: {}, {}", BufferUtils.toUTF8String(frame.getData()), frame));
                        if (frame.isEndStream()) {
                            phaser.arrive(); // 1
                        }
                        callback.succeeded();
                    }
                });

        final Stream clientStream = streamPromise.get();
        writeln("client stream id: " ~ clientStream.getId());

        clientStream.data(new DataFrame(clientStream.getId(),
                toBuffer("hello world!", StandardCharsets.UTF_8), false), new Callback() {
            override
            public void succeeded() {
                clientStream.data(new DataFrame(clientStream.getId(),
                        toBuffer("big hello world!", StandardCharsets.UTF_8), true), Callback.NOOP);
            }
        });
        phaser.arriveAndAwaitAdvance();
    }
}
