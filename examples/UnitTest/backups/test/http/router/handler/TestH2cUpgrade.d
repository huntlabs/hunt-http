module test.http.router.handler;

import hunt.http.client.http2;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.HTTP2Configuration;
import hunt.http.codec.http.stream.HTTPConnection;
import hunt.http.codec.http.stream.HTTPOutputStream;
import hunt.http.server.http.HTTP2Server;
import hunt.http.server.http.ServerHTTPHandler;
import hunt.http.utils.concurrent.FuturePromise;
import hunt.container.BufferUtils;
import hunt.util.Assert;
import hunt.util.Test;

import java.io.IOException;
import java.io.UnsupportedEncodingException;
import hunt.container.ByteBuffer;
import java.nio.charset.StandardCharsets;
import hunt.container.ArrayList;
import java.util.HashMap;
import hunt.container.List;
import java.util.Map;
import java.util.concurrent.Phaser;

import hunt.http.utils.io.BufferUtils.toBuffer;


/**
 * 
 */
public class TestH2cUpgrade extends AbstractHTTPHandlerTest {

    private static final int timeout = 20 * 1000;
    private static final int corePoolSize = 4;
    private static final int loop = 10;

    
    public void test() {
        HTTP2Server server = createServer();
        HTTP2Client client = createClient();

        FuturePromise<HTTPClientConnection> promise = new FuturePromise<>();
        client.connect(host, port, promise);

        final HTTPClientConnection httpConnection = promise.get();
        final HTTP2ClientConnection clientConnection = upgradeHttp2(client.getHttp2Configuration(), httpConnection);

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

    private static class TestH2cHandler extends ClientHTTPHandler.Adapter {

        protected final ByteBuffer[] buffers;
        protected final List!(ByteBuffer) contentList = new ArrayList<>();

        public TestH2cHandler() {
            buffers = null;
        }

        public TestH2cHandler(ByteBuffer[] buffers) {
            this.buffers = buffers;
        }

        override
        public void continueToSendData(MetaData.Request request, MetaData.Response response, HTTPOutputStream output,
                                       HTTPConnection connection) {
            writeln("client received 100 continue");
            if (buffers != null) {
                writeln("buffers: " ~ buffers.length);
                try (HTTPOutputStream out = output) {
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
        public bool content(ByteBuffer item, MetaData.Request request, MetaData.Response response,
                               HTTPOutputStream output,
                               HTTPConnection connection) {
            writeln("client received data: " ~ BufferUtils.toUTF8String(item));
            contentList.add(item);
            return false;
        }

        override
        public void badMessage(int status, string reason, MetaData.Request request, MetaData.Response response,
                               HTTPOutputStream output, HTTPConnection connection) {
            writeln("Client received the bad message. " ~ reason);
        }

        override
        public void earlyEOF(MetaData.Request request, MetaData.Response response,
                             HTTPOutputStream output,
                             HTTPConnection connection) {
            writeln("Client is early EOF. ");
        }

    }

    private HTTP2Client createClient() {
        final HTTP2Configuration config = new HTTP2Configuration();
        config.getTcpConfiguration().setTimeout(timeout);
        config.getTcpConfiguration().setAsynchronousCorePoolSize(corePoolSize);
        return new HTTP2Client(config);
    }

    private HTTP2ClientConnection upgradeHttp2(HTTP2Configuration http2Configuration, HTTPClientConnection httpConnection) {
        HTTPClientRequest request = new HTTPClientRequest("GET", "/index");

        Map<Integer, Integer> settings = new HashMap<>();
        settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
        settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());
        SettingsFrame settingsFrame = new SettingsFrame(settings, false);

        FuturePromise<HTTP2ClientConnection> http2Promise = new FuturePromise<>();

        ClientHTTPHandler upgradeHandler = new TestH2cHandler() {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                printResponse(request, response, BufferUtils.toString(contentList));
                Assert.assertThat(response.getStatus(), is(HttpStatus.SWITCHING_PROTOCOLS_101));
                Assert.assertThat(response.getFields().get(HttpHeader.UPGRADE), is("h2c"));
                return true;
            }
        };

        ClientHTTPHandler h2ResponseHandler = new TestH2cHandler() {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                writeln("Client received init status: " ~ response.getStatus());
                string content = BufferUtils.toString(contentList);
                printResponse(request, response, content);
                Assert.assertThat(response.getStatus(), is(HttpStatus.OK_200));
                Assert.assertThat(content, is("receive initial stream successful"));
                return true;
            }
        };

        httpConnection.upgradeHTTP2(request, settingsFrame, http2Promise, upgradeHandler, h2ResponseHandler);
        writeln("get the h2 connection");
        return http2Promise.get();
    }

    private void test404(Phaser phaser, HTTP2ClientConnection clientConnection) {
        writeln("Client test 404.");
        MetaData.Request get = new MetaData.Request("GET", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/test2", HttpVersion.HTTP_1_1, new HttpFields());
        clientConnection.send(get, new TestH2cHandler() {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                printResponse(request, response, BufferUtils.toString(contentList));
                Assert.assertThat(response.getStatus(), is(HttpStatus.NOT_FOUND_404));
                phaser.arrive();
                writeln("Complete task: " ~ phaser.getArrivedParties());
                return true;
            }
        });
    }

    private void sendData(Phaser phaser, HTTP2ClientConnection clientConnection) throws UnsupportedEncodingException {
        writeln("Client sends data.");
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        MetaData.Request post2 = new MetaData.Request("POST", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/data", HttpVersion.HTTP_1_1, fields);
        clientConnection.send(post2, new ByteBuffer[]{
                ByteBuffer.wrap("test data 2".getBytes("UTF-8")),
                ByteBuffer.wrap("finished test data 2".getBytes("UTF-8"))}, new TestH2cHandler() {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                return dataComplete(phaser, BufferUtils.toString(contentList), request, response);
            }
        });
    }

    private void sendDataWithContinuation(Phaser phaser, HTTP2ClientConnection clientConnection) throws UnsupportedEncodingException {
        writeln("Client sends data with continuation");
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        MetaData.Request post = new MetaData.Request("POST", HttpScheme.HTTP,
                new HostPortHttpField(host ~ ":" ~ port),
                "/data", HttpVersion.HTTP_1_1, fields);
        clientConnection.sendRequestWithContinuation(post, new TestH2cHandler(new ByteBuffer[]{
                ByteBuffer.wrap("hello world!".getBytes("UTF-8")),
                ByteBuffer.wrap("big hello world!".getBytes("UTF-8"))}) {
            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response,
                                           HTTPOutputStream output,
                                           HTTPConnection connection) {
                return dataComplete(phaser, BufferUtils.toString(contentList), request, response);
            }
        });
    }

    private void printResponse(MetaData.Request request, MetaData.Response response, string content) {
        writeln("client---------------------------------");
        writeln("client received frame: " ~ request ~ ", " ~ response);
        writeln(response.getFields());
        writeln(content);
        writeln("client---------------------------------end");
        writeln();
    }

    public bool dataComplete(Phaser phaser, string content, MetaData.Request request, MetaData.Response response) {
        printResponse(request, response, content);
        Assert.assertThat(response.getStatus(), is(HttpStatus.OK_200));
        Assert.assertThat(content, is("Receive data stream successful. Thank you!"));
        phaser.arrive();
        writeln("Complete task: " ~ phaser.getArrivedParties());
        return true;
    }

    private HTTP2Server createServer() {
        final HTTP2Configuration config = new HTTP2Configuration();
        config.getTcpConfiguration().setTimeout(timeout);
        config.getTcpConfiguration().setAsynchronousCorePoolSize(corePoolSize);
        HTTP2Server server = new HTTP2Server(host, port, config, new ServerHTTPHandlerAdapter() {

            override
            public void badMessage(int status, string reason, MetaData.Request request, MetaData.Response response,
                                   HTTPOutputStream output, HTTPConnection connection) {
                writeln("Server received the bad message. " ~ reason);
            }

            override
            public void earlyEOF(MetaData.Request request, MetaData.Response response,
                                 HTTPOutputStream output,
                                 HTTPConnection connection) {
                writeln("Server is early EOF. ");
            }

            override
            public bool content(ByteBuffer item, MetaData.Request request, MetaData.Response response, HTTPOutputStream output,
                                   HTTPConnection connection) {
//                writeln("Server received data: " ~ BufferUtils.toString(item, StandardCharsets.UTF_8));
                return false;
            }

            override
            public bool messageComplete(MetaData.Request request, MetaData.Response response, HTTPOutputStream outputStream,
                                           HTTPConnection connection) {
                writeln("Server received request: " ~ request ~ ", " ~ outputStream.getClass() ~ ", " ~ connection.getHttpVersion());
                HttpURI uri = request.getURI();
                switch (uri.getPath()) {
                    case "/index":
                        response.setStatus(HttpStatus.Code.OK.getCode());
                        response.setReason(HttpStatus.Code.OK.getMessage());
                        try (HTTPOutputStream output = outputStream) {
                            output.writeWithContentLength(toBuffer("receive initial stream successful", StandardCharsets.UTF_8));
                        } catch (IOException e) {
                            e.printStackTrace();
                        }
                        break;
                    case "/data":
                        response.setStatus(HttpStatus.Code.OK.getCode());
                        response.setReason(HttpStatus.Code.OK.getMessage());
                        try (HTTPOutputStream output = outputStream) {
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
                        try (HTTPOutputStream output = outputStream) {
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
