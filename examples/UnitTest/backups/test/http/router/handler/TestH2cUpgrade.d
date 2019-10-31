module test.http.router.handler;

import hunt.http.client.http2;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model;
import hunt.http.HttpOptions;
import hunt.http.HttpConnection;
import hunt.http.HttpOutputStream;
import hunt.http.server.HttpServer;
import hunt.http.server.ServerHttpHandler;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.collection.BufferUtils;
import hunt.Assert;
import hunt.util.Test;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import hunt.collection.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.collection.ArrayList;
import java.util.HashMap;
import hunt.collection.List;
import java.util.Map;
import hunt.concurrency.Phaser;

import hunt.http.utils.io.BufferUtils.toBuffer;


/**
 * 
 */
public class TestH2cUpgrade extends AbstractHttpHandlerTest {

    private static final int timeout = 20 * 1000;
    private static final int corePoolSize = 4;
    private static final int loop = 10;

    
    public void test() {
        HttpServer server = createServer();
        HttpClient client = createClient();

        FuturePromise<HttpClientConnection> promise = new FuturePromise<>();
        client.connect(host, port, promise);

        final HttpClientConnection httpConnection = promise.get();
        final Http2ClientConnection clientConnection = upgradeHttp2(client.getHttpOptions(), httpConnection);

        Phaser phaser = new Phaser(loop * 3 + 1);
        clientConnection.onClose(c -> {
            phaser.forceTermination();
            writeln("The client connection closed.");
        }).onException((c, ex) -> {
            phaser.forceTermination();
            ex.printStackTrace();
        });

        for (int j = 0; j < loop; j++) {
            sendData(phaser, clientConnection);
            sendDataWithContinuation(phaser, clientConnection);
            test404(phaser, clientConnection);
        }

        try {
            phaser.arriveAndAwaitAdvance();
        } catch (Exception e) {
            writeln(e.getClass() ~ ", msg: " ~ e.getMessage());
        }

        writeln("Completed all tasks.");
        server.stop();
        client.stop();
    }

    private static class TestH2cHandler extends AbstractClientHttpHandler {

        protected final ByteBuffer[] buffers;
        protected final List!(ByteBuffer) contentList = new ArrayList<>();

        public TestH2cHandler() {
            buffers = null;
        }

        public TestH2cHandler(ByteBuffer[] buffers) {
            this.buffers = buffers;
        }

        override
        public void continueToSendData(HttpRequest request, HttpResponse response, HttpOutputStream output,
                                       HttpConnection connection) {
            writeln("client received 100 continue");
            if (buffers != null) {
                writeln("buffers: " ~ buffers.length);
                try (HttpOutputStream out = output) {
                    for (ByteBuffer buf : buffers) {
                        out.write(buf);
                    }
                } catch (IOException e) {
                    e.printStackTrace();
                }
                writeln("client sends buffers completely");
            }
        }

        override
        public bool content(ByteBuffer item, HttpRequest request, HttpResponse response,
                               HttpOutputStream output,
                               HttpConnection connection) {
            writeln("client received data: " ~ BufferUtils.toUTF8String(item));
            contentList.add(item);
            return false;
        }

        override
        public void badMessage(int status, string reason, HttpRequest request, HttpResponse response,
                               HttpOutputStream output, HttpConnection connection) {
            writeln("Client received the bad message. " ~ reason);
        }

        override
        public void earlyEOF(HttpRequest request, HttpResponse response,
                             HttpOutputStream output,
                             HttpConnection connection) {
            writeln("Client is early EOF. ");
        }

    }

    private HttpClient createClient() {
        final HttpOptions config = new HttpOptions();
        config.getTcpConfiguration().setTimeout(timeout);
        config.getTcpConfiguration().setAsynchronousCorePoolSize(corePoolSize);
        return new HttpClient(config);
    }

    private Http2ClientConnection upgradeHttp2(HttpOptions http2Configuration, HttpClientConnection httpConnection) {
        HttpClientRequest request = new HttpClientRequest("GET", "/index");

        Map<Integer, Integer> settings = new HashMap<>();
        settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
        settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
        SettingsFrame settingsFrame = new SettingsFrame(settings, false);

        FuturePromise<Http2ClientConnection> http2Promise = new FuturePromise<>();

        ClientHttpHandler upgradeHandler = new TestH2cHandler() {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                printResponse(request, response, BufferUtils.toString(contentList));
                Assert.assertThat(response.getStatus(), is(HttpStatus.SWITCHING_PROTOCOLS_101));
                Assert.assertThat(response.getFields().get(HttpHeader.UPGRADE), is("h2c"));
                return true;
            }
        };

        ClientHttpHandler h2ResponseHandler = new TestH2cHandler() {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                writeln("Client received init status: " ~ response.getStatus());
                string content = BufferUtils.toString(contentList);
                printResponse(request, response, content);
                Assert.assertThat(response.getStatus(), is(HttpStatus.OK_200));
                Assert.assertThat(content, is("receive initial stream successful"));
                return true;
            }
        };

        httpConnection.upgradeHttp2(request, settingsFrame, http2Promise, upgradeHandler, h2ResponseHandler);
        writeln("get the h2 connection");
        return http2Promise.get();
    }

    private void test404(Phaser phaser, Http2ClientConnection clientConnection) {
        writeln("Client test 404.");
        HttpRequest get = new HttpRequest("GET", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/test2", HttpVersion.HTTP_1_1, new HttpFields());
        clientConnection.send(get, new TestH2cHandler() {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                printResponse(request, response, BufferUtils.toString(contentList));
                Assert.assertThat(response.getStatus(), is(HttpStatus.NOT_FOUND_404));
                phaser.arrive();
                writeln("Complete task: " ~ phaser.getArrivedParties());
                return true;
            }
        });
    }

    private void sendData(Phaser phaser, Http2ClientConnection clientConnection) throws UnsupportedEncodingException {
        writeln("Client sends data.");
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        HttpRequest post2 = new HttpRequest("POST", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/data", HttpVersion.HTTP_1_1, fields);
        clientConnection.send(post2, new ByteBuffer[]{
                BufferUtils.toBuffer("test data 2".getBytes("UTF-8")),
                BufferUtils.toBuffer("finished test data 2".getBytes("UTF-8"))}, new TestH2cHandler() {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                return dataComplete(phaser, BufferUtils.toString(contentList), request, response);
            }
        });
    }

    private void sendDataWithContinuation(Phaser phaser, Http2ClientConnection clientConnection) throws UnsupportedEncodingException {
        writeln("Client sends data with continuation");
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        HttpRequest post = new HttpRequest("POST", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/data", HttpVersion.HTTP_1_1, fields);
        clientConnection.sendRequestWithContinuation(post, new TestH2cHandler(new ByteBuffer[]{
                BufferUtils.toBuffer("hello world!".getBytes("UTF-8")),
                BufferUtils.toBuffer("big hello world!".getBytes("UTF-8"))}) {
            override
            public bool messageComplete(HttpRequest request, HttpResponse response,
                                           HttpOutputStream output,
                                           HttpConnection connection) {
                return dataComplete(phaser, BufferUtils.toString(contentList), request, response);
            }
        });
    }

    private void printResponse(HttpRequest request, HttpResponse response, string content) {
        writeln("client---------------------------------");
        writeln("client received frame: " ~ request ~ ", " ~ response);
        writeln(response.getFields());
        writeln(content);
        writeln("client---------------------------------end");
        writeln();
    }

    public bool dataComplete(Phaser phaser, string content, HttpRequest request, HttpResponse response) {
        printResponse(request, response, content);
        Assert.assertThat(response.getStatus(), is(HttpStatus.OK_200));
        Assert.assertThat(content, is("Receive data stream successful. Thank you!"));
        phaser.arrive();
        writeln("Complete task: " ~ phaser.getArrivedParties());
        return true;
    }

    private HttpServer createServer() {
        final HttpOptions config = new HttpOptions();
        config.getTcpConfiguration().setTimeout(timeout);
        config.getTcpConfiguration().setAsynchronousCorePoolSize(corePoolSize);
        HttpServer server = new HttpServer(host, port, config, new ServerHttpHandlerAdapter() {

            override
            public void badMessage(int status, string reason, HttpRequest request, HttpResponse response,
                                   HttpOutputStream output, HttpConnection connection) {
                writeln("Server received the bad message. " ~ reason);
            }

            override
            public void earlyEOF(HttpRequest request, HttpResponse response,
                                 HttpOutputStream output,
                                 HttpConnection connection) {
                writeln("Server is early EOF. ");
            }

            override
            public bool content(ByteBuffer item, HttpRequest request, HttpResponse response, HttpOutputStream output,
                                   HttpConnection connection) {
//                writeln("Server received data: " ~ BufferUtils.toString(item, StandardCharsets.UTF_8));
                return false;
            }

            override
            public bool messageComplete(HttpRequest request, HttpResponse response, HttpOutputStream outputStream,
                                           HttpConnection connection) {
                writeln("Server received request: " ~ request ~ ", " ~ outputStream.getClass() ~ ", " ~ connection.getHttpVersion());
                HttpURI uri = request.getURI();
                switch (uri.getPath()) {
                    case "/index":
                        response.setStatus(HttpStatus.Code.OK.getCode());
                        response.setReason(HttpStatus.Code.OK.getMessage());
                        try (HttpOutputStream output = outputStream) {
                            output.writeWithContentLength(toBuffer("receive initial stream successful", StandardCharsets.UTF_8));
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                        break;
                    case "/data":
                        response.setStatus(HttpStatus.Code.OK.getCode());
                        response.setReason(HttpStatus.Code.OK.getMessage());
                        try (HttpOutputStream output = outputStream) {
                            output.writeWithContentLength(new ByteBuffer[]{
                                    toBuffer("Receive data stream successful. ", StandardCharsets.UTF_8),
                                    toBuffer("Thank you!", StandardCharsets.UTF_8)
                            });
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                        break;
                    default:
                        response.setStatus(HttpStatus.Code.NOT_FOUND.getCode());
                        response.setReason(HttpStatus.Code.NOT_FOUND.getMessage());
                        try (HttpOutputStream output = outputStream) {
                            output.writeWithContentLength(toBuffer(uri.getPath() ~ " not found", StandardCharsets.UTF_8));
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                        break;
                }
//                writeln("server--------------------------------end");
                return true;
            }
        });
        server.start();
        return server;
    }

}
