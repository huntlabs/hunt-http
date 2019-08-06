module test.codec.http2.decode.Http2DecoderTest;

import hunt.http.codec.http.encode.Http2Generator;
import hunt.http.codec.http.encode.HeadersGenerator;
import hunt.http.codec.http.encode.SettingsGenerator;

import hunt.http.codec.http.frame;
import hunt.http.codec.http.model;

import hunt.http.HttpOptions;
import hunt.http.codec.http.stream.Session;
import hunt.http.codec.http.stream.Stream;
import hunt.http.codec.CommonEncoder;

import hunt.http.server.Http2ServerConnection;
import hunt.http.server.Http2ServerDecoder;
import hunt.http.server.ServerSessionListener;

import hunt.collection;
import hunt.Exceptions;
import hunt.util.Common;
import hunt.net.Connection;
import hunt.Assert;
import hunt.util.Common;

import std.conv;
import std.random;
import std.stdio;
import std.socket;


class Http2DecoderTest {

    void testData() {
        byte[] smallContent = new byte[22];
        byte[] bigContent = new byte[50];
        auto rnd = Random(2018);
        for(size_t i=0; i<smallContent.length; i++ )   smallContent[i] = cast(byte) uniform(byte.min, byte.max, rnd);
        for(size_t i=0; i<bigContent.length; i++ )   bigContent[i] = cast(byte) uniform(byte.min, byte.max, rnd);

        MockSessionFactory factory = new MockSessionFactory();
        Http2ServerDecoder decoder = new Http2ServerDecoder();
        TcpSession session = factory.create();
        HttpConfiguration http2Configuration = new HttpConfiguration();
        http2Configuration.setFlowControlStrategy("simple");

        Map!(int, int) settings = new HashMap!(int, int)();
        settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
        settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());


        class ServerSessionListenerTester : ServerSessionListener
        {

            Map!(int, int) onPreface(StreamSession session) {
                writeln("on preface: " ~ session.isClosed().to!string());
                Assert.assertThat(session.isClosed(), (false));
                return settings;
            }

            Stream.Listener onNewStream(Stream stream, HeadersFrame frame) {
                writeln("on new stream: " ~ stream.getId().to!string);
                writeln("on new stream headers: " ~ frame.getMetaData().toString());

                Assert.assertThat(stream.getId(), (5));
                Assert.assertThat(frame.getMetaData().getHttpVersion(), (HttpVersion.HTTP_2));
                Assert.assertThat(frame.getMetaData().getFields().get("User-Agent"), ("Hunt Client 1.0"));
                Assert.assertThat(frame.getMetaData().getFields().get(HttpHeader.CONTENT_LENGTH), ("72"));

                HttpRequest request = cast(HttpRequest) frame.getMetaData();
                Assert.assertThat(request.getMethod(), ("POST"));
                Assert.assertThat(request.getURI().getPath(), ("/data"));
                Assert.assertThat(request.getURI().getPort(), (8080));
                Assert.assertThat(request.getURI().getHost(), ("localhost"));


                return new class Stream.Listener {

                    void onReset(Stream stream, ResetFrame frame, Callback callback) {
                        try {
                            onReset(stream, frame);
                            callback.succeeded();
                        } catch (Exception x) {
                            callback.failed(x);
                        }
                    }

                    // override
                    void onHeaders(Stream stream, HeadersFrame frame) {
                        writeln("on headers: " ~ frame.getMetaData().toString());
                    }

                    // override
                    Stream.Listener onPush(Stream stream, PushPromiseFrame frame) {
                        return null;
                    }

                    // override
                    void onData(Stream stream, DataFrame frame, Callback callback) {
                        Assert.assertThat(stream.getId(), (5));
                        if (frame.isEndStream()) {
                            Assert.assertThat(frame.remaining(), (50));
                            Assert.assertThat(frame.getData().array(), (bigContent));
                        } else {
                            Assert.assertThat(frame.remaining(), (22));
                            Assert.assertThat(frame.getData().array(), (smallContent));
                        }
                        writeln("data size:" ~ frame.remaining().to!string);
                        callback.succeeded();
                    }

                    // override
                    void onReset(Stream stream, ResetFrame frame) {

                    }

                    // override
                    bool onIdleTimeout(Stream stream, Exception x) {
                        return true;
                    }

                    override string toString()
                    {
                        return super.toString();
                    }
                };
            }

            override
            void onSettings(StreamSession session, SettingsFrame frame) {
                writeln("on settings: " ~ frame.toString());
                Assert.assertThat(frame.getSettings().get(SettingsFrame.INITIAL_WINDOW_SIZE), (http2Configuration.getInitialStreamSendWindow()));
            }

            override
            void onPing(StreamSession session, PingFrame frame) {
            }

            override
            void onReset(StreamSession session, ResetFrame frame) {
            }

            override
            void onClose(StreamSession session, GoAwayFrame frame) {
            }


		    void onClose(StreamSession session, GoAwayFrame frame, Callback callback)
            {
                try
                {
                    onClose(session, frame);
                    callback.succeeded();
                }
                catch (Exception x)
                {
                    callback.failed(x);
                }
            }

		    void onFailure(StreamSession session, Exception failure, Callback callback)
            {
                try
                {
                    onFailure(session, failure);
                    callback.succeeded();
                }
                catch (Exception x)
                {
                    callback.failed(x);
                }
            }

            override
            void onFailure(StreamSession session, Exception failure) {
            }

            override
            void onAccept(StreamSession session) {
            }

            override
            bool onIdleTimeout(StreamSession session) {
                // TODO Auto-generated method stub
                return false;
            }
        }

        Http2ServerConnection http2ServerConnection = new Http2ServerConnection(http2Configuration, session, null,
                new ServerSessionListenerTester() );

        session.attachObject(http2ServerConnection);

        int streamId = 5;
        HttpFields fields = new HttpFields();
        fields.put(HttpHeader.ACCEPT, "text/html");
        fields.put(HttpHeader.USER_AGENT, "Hunt Client 1.0");
        fields.put(HttpHeader.CONTENT_LENGTH, "72");
        HttpRequest metaData = new HttpRequest("POST", HttpScheme.HTTP,
                new HostPortHttpField("localhost:8080"), "/data", HttpVersion.HTTP_2, fields);

        DataFrame smallDataFrame = new DataFrame(streamId, BufferUtils.toBuffer(smallContent), false);
        DataFrame bigDataFrame = new DataFrame(streamId, BufferUtils.toBuffer(bigContent), true);

        Http2Generator generator = new Http2Generator(http2Configuration.getMaxDynamicTableSize(), http2Configuration.getMaxHeaderBlockFragment());

        HeadersGenerator headersGenerator = generator.getControlGenerator!(HeadersGenerator)(FrameType.HEADERS);
        SettingsGenerator settingsGenerator = generator.getControlGenerator!(SettingsGenerator)(FrameType.SETTINGS);

        List!(ByteBuffer) list = new LinkedList!(ByteBuffer)();
        list.add(BufferUtils.toBuffer(cast(byte[])PrefaceFrame.PREFACE_BYTES));
        list.add(settingsGenerator.generateSettings(settings, false));
        list.addAll(headersGenerator.generateHeaders(streamId, metaData, null, false));
        list.addAll(generator.data(smallDataFrame, cast(int)smallContent.length)[1]);
        list.addAll(generator.data(bigDataFrame, cast(int)bigContent.length)[1]);

        foreach (ByteBuffer buffer ; list) {
            decoder.decode(buffer, session);
        }
        writeln("out data: " ~ factory.output.size().to!string());
        assert(factory.output.size()>(1));
        assert(factory.output.size() == 5);
        http2ServerConnection.close();
    }

    
    void testHeaders() {
        MockSessionFactory factory = new MockSessionFactory();
        Http2ServerDecoder decoder = new Http2ServerDecoder();
        TcpSession session = factory.create();
        HttpConfiguration http2Configuration = new HttpConfiguration();
        Http2ServerConnection http2ServerConnection = new Http2ServerConnection(http2Configuration, session, null,
                new class ServerSessionListener {

                    override
                    Map!(int, int) onPreface(StreamSession session) {
                        writeln("on preface: " ~ session.isClosed().to!string());
                        Assert.assertThat(session.isClosed(), (false));
                        return null;
                    }

                    // override
                    Stream.Listener onNewStream(Stream stream, HeadersFrame frame) {
                        writeln("on new stream: " ~ stream.getId().to!string);
                        writeln("on new stream headers: " ~ frame.getMetaData().toString());

                        Assert.assertThat(stream.getId(), (5));
                        Assert.assertThat(frame.getMetaData().getHttpVersion(), (HttpVersion.HTTP_2));
                        Assert.assertThat(frame.getMetaData().getFields().get("User-Agent"), ("Hunt Client 1.0"));

                        HttpRequest request = cast(HttpRequest) frame.getMetaData();
                        Assert.assertThat(request.getMethod(), ("GET"));
                        Assert.assertThat(request.getURI().getPath(), ("/index"));
                        Assert.assertThat(request.getURI().getPort(), (8080));
                        Assert.assertThat(request.getURI().getHost(), ("localhost"));
                        return new class Stream.Listener {

                            void onReset(Stream stream, ResetFrame frame, Callback callback) {
                                try {
                                    onReset(stream, frame);
                                    callback.succeeded();
                                } catch (Exception x) {
                                    callback.failed(x);
                                }
                            }

                            // override
                            void onHeaders(Stream stream, HeadersFrame frame) {
                                writeln("on headers: " ~ frame.getMetaData().toString());
                            }

                            // override
                            Stream.Listener onPush(Stream stream, PushPromiseFrame frame) {
                                return null;
                            }

                            // override
                            void onData(Stream stream, DataFrame frame, Callback callback) {

                            }

                            // override
                            void onReset(Stream stream, ResetFrame frame) {

                            }

                            // override
                            bool onIdleTimeout(Stream stream, Exception x) {
                                return true;
                            }

                            override string toString()
                            {
                                return super.toString();
                            }
                        };
                    }

                    override
                    void onSettings(StreamSession session, SettingsFrame frame) {
                        writeln("on settings: " ~ frame.toString());
                        Assert.assertThat(frame.getSettings().get(SettingsFrame.INITIAL_WINDOW_SIZE), 
                            (http2Configuration.getInitialStreamSendWindow()));
                    }

                    override
                    void onPing(StreamSession session, PingFrame frame) {
                    }

                    override
                    void onReset(StreamSession session, ResetFrame frame) {
                    }

                    override
                    void onClose(StreamSession session, GoAwayFrame frame) {
                    }

                    override
                    void onFailure(StreamSession session, Exception failure) {
                    }

                    void onClose(StreamSession session, GoAwayFrame frame, Callback callback)
                    {
                        try
                        {
                            onClose(session, frame);
                            callback.succeeded();
                        }
                        catch (Exception x)
                        {
                            callback.failed(x);
                        }
                    }

                    void onFailure(StreamSession session, Exception failure, Callback callback)
                    {
                        try
                        {
                            onFailure(session, failure);
                            callback.succeeded();
                        }
                        catch (Exception x)
                        {
                            callback.failed(x);
                        }
                    }

                    override
                    void onAccept(StreamSession session) {
                    }

                    override
                    bool onIdleTimeout(StreamSession session) {
                        // TODO Auto-generated method stub
                        return false;
                    }
                });
        session.attachObject(http2ServerConnection);

        int streamId = 5;
        HttpFields fields = new HttpFields();
        fields.put("Accept", "text/html");
        fields.put("User-Agent", "Hunt Client 1.0");
        HttpRequest metaData = new HttpRequest("GET", HttpScheme.HTTP,
                new HostPortHttpField("localhost:8080"), "/index", HttpVersion.HTTP_2, fields);
        Map!(int, int) settings = new HashMap!(int, int)();
        settings.put(SettingsFrame.HEADER_TABLE_SIZE, http2Configuration.getMaxDynamicTableSize());
        settings.put(SettingsFrame.INITIAL_WINDOW_SIZE, http2Configuration.getInitialStreamSendWindow());

        Http2Generator generator = new Http2Generator(http2Configuration.getMaxDynamicTableSize(), 
            http2Configuration.getMaxHeaderBlockFragment());

        HeadersGenerator headersGenerator = generator.getControlGenerator!HeadersGenerator(FrameType.HEADERS);
        SettingsGenerator settingsGenerator = generator.getControlGenerator!SettingsGenerator(FrameType.SETTINGS);

        List!(ByteBuffer) list = new LinkedList!(ByteBuffer)();
        list.add(BufferUtils.toBuffer(cast(byte[])PrefaceFrame.PREFACE_BYTES));
        list.add(settingsGenerator.generateSettings(settings, false));
        list.addAll(headersGenerator.generateHeaders(streamId, metaData, null, true));
        foreach (ByteBuffer buffer ; list) {
            decoder.decode(buffer, session);
        }

        assert(factory.output.size()> 0);
        writeln("out data: " ~ factory.output.size().to!string);
        assert(factory.output.size()>1);
        http2ServerConnection.close();
    }
}



class MockSessionFactory
{
    LinkedList!ByteBuffer output;
    private static CommonEncoder encoder;

    static this()
    {
        encoder = new CommonEncoder();
    }

    this()
    {
        output = new LinkedList!ByteBuffer();
    }

    static class AbstractMockSession : TcpSession {
        Object attachment;
        bool _isOpen = true;
        LinkedList!(ByteBuffer) outboundData;

        this(LinkedList!(ByteBuffer) outboundData) {
            this.outboundData = outboundData;
        }

        override
        void attachObject(Object attachment) {
            this.attachment = attachment;
        }

        override
        Object getAttachment() {
            return attachment;
        }

        override
        void encode(Object message) {
            encoder.encode(message, this);
        }

        override
        bool isOpen() {
            return _isOpen;
        }

        override
        void write(ByteBuffer byteBuffer, Callback callback) {
            outboundData.offer(byteBuffer);
            byteBuffer.flip();
            callback.succeeded();
        }

        override
        void write(ByteBuffer[] buffers, Callback callback) {
            foreach (ByteBuffer buffer ; buffers) {
                outboundData.offer(buffer);
                buffer.flip();
            }
            callback.succeeded();

        }

        override
        void write(Collection!(ByteBuffer) buffers, Callback callback) {
            write(buffers.toArray(), callback); // BufferUtils.EMPTY_BYTE_BUFFER_ARRAY
        }

        // override
        // void write(OutputEntry!(?) entry) {
        //     if (entry instanceof ByteBufferOutputEntry) {
        //         ByteBufferOutputEntry outputEntry = (ByteBufferOutputEntry) entry;
        //         write(outputEntry.getData(), outputEntry.getCallback());
        //     } else {
        //         ByteBufferArrayOutputEntry outputEntry = (ByteBufferArrayOutputEntry) entry;
        //         write(outputEntry.getData(), outputEntry.getCallback());
        //     }
        // }

        override
        void closeNow() {
            _isOpen = false;
        }


        void notifyMessageReceived(Object message){ implementationMissing(false); }

        void encode(ByteBuffer[] messages){ 
            // implementationMissing(false); 
            foreach(ByteBuffer message; messages)
                encoder.encode(message, this);
            }

        int getId(){ return 0; }

version(HUNT_METRIC) {
        long getOpenTime(){ implementationMissing(false); return 0; }

        long getCloseTime(){ implementationMissing(false); return 0; }

        long getDuration(){ implementationMissing(false); return 0; }

        long getLastReadTime(){ implementationMissing(false); return 0; }

        long getLastWrittenTime(){ implementationMissing(false); return 0; }

        long getLastActiveTime(){ implementationMissing(false); return 0; }

        size_t getReadBytes(){ implementationMissing(false); return 0; }

        size_t getWrittenBytes(){ implementationMissing(false); return 0; }

        long getIdleTimeout() { implementationMissing(false); return 0; }

        override string toString() { return ""; }
}
        void close(){  }

        void shutdownOutput(){ implementationMissing(false); }

        void shutdownInput(){ implementationMissing(false); }

        bool isClosed(){ implementationMissing(false); return false; }

        bool isShutdownOutput(){ implementationMissing(false); return false; }

        bool isShutdownInput(){ implementationMissing(false); return false; }

        bool isWaitingForClose(){ implementationMissing(false); return false; }

        Address getLocalAddress(){ return new InternetAddress("127.0.0.1", 8080); }

        Address getRemoteAddress(){ return new InternetAddress("127.0.0.1", 0); }

        long getMaxIdleTimeout() { implementationMissing(false); return 0; }

    }

    TcpSession create()
    {
        AbstractMockSession s = new AbstractMockSession(output);
        return s;
    }
}

