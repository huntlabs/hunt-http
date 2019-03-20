module test.codec.websocket.model.extension;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.TextFrame;
import hunt.http.codec.websocket.frame.WebSocketFrame;
import hunt.http.codec.websocket.model;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.model.extension.ExtensionFactory;
import hunt.http.codec.websocket.model.extension.WebSocketExtensionFactory;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.util.TypeUtils;
import hunt.Assert;
import test.codec.websocket.ByteBufferAssert;
import test.codec.websocket.IncomingFramesCapture;
import test.codec.websocket.UnitParser;

import hunt.collection.ByteBuffer;
import java.util.Collections;




public class ExtensionTool {
    public class Tester {
        private string requestedExtParams;
        private ExtensionConfig extConfig;
        private Extension ext;
        private Parser parser;
        private IncomingFramesCapture capture;

        private Tester(string parameterizedExtension) {
            this.requestedExtParams = parameterizedExtension;
            this.extConfig = ExtensionConfig.parse(parameterizedExtension);
            Class<?> extClass = factory.getExtension(extConfig.getName());
            Assert.assertThat("extClass", extClass, notNullValue());

            this.parser = new UnitParser(policy);
        }

        public string getRequestedExtParams() {
            return requestedExtParams;
        }

        public void assertNegotiated(string expectedNegotiation) {
            this.ext = factory.newInstance(extConfig);
            if (ext instanceof AbstractExtension) {
                ((AbstractExtension) ext).setPolicy(policy);
            }

            this.capture = new IncomingFramesCapture();
            this.ext.setNextIncomingFrames(capture);

            this.parser.configureFromExtensions(Collections.singletonList(ext));
            this.parser.setIncomingFramesHandler(ext);
        }

        public void parseIncomingHex(string... rawhex) {
            int parts = rawhex.length;
            byte net[];

            for (int i = 0; i < parts; i++) {
                string hex = rawhex[i].replaceAll("\\s*(0x)?", "");
                net = TypeUtils.fromHexString(hex);
                parser.parse(BufferUtils.toBuffer(net));
            }
        }

        public void assertHasFrames(string... textFrames) {
            Frame frames[] = new Frame[textFrames.length];
            for (int i = 0; i < frames.length; i++) {
                frames[i] = new TextFrame().setPayload(textFrames[i]);
            }
            assertHasFrames(frames);
        }

        public void assertHasFrames(Frame... expectedFrames) {
            int expectedCount = expectedFrames.length;
            capture.assertFrameCount(expectedCount);

            for (int i = 0; i < expectedCount; i++) {
                WebSocketFrame actual = capture.getFrames().poll();

                string prefix = string.format("frame[%d]", i);
                Assert.assertThat(prefix ~ ".opcode", actual.getOpCode(), is(expectedFrames[i].getOpCode()));
                Assert.assertThat(prefix ~ ".fin", actual.isFin(), is(expectedFrames[i].isFin()));
                Assert.assertThat(prefix ~ ".rsv1", actual.isRsv1(), is(false));
                Assert.assertThat(prefix ~ ".rsv2", actual.isRsv2(), is(false));
                Assert.assertThat(prefix ~ ".rsv3", actual.isRsv3(), is(false));

                ByteBuffer expected = expectedFrames[i].getPayload().slice();
                Assert.assertThat(prefix ~ ".payloadLength", actual.getPayloadLength(), is(expected.remaining()));
                ByteBufferAssert.assertEquals(prefix ~ ".payload", expected, actual.getPayload().slice());
            }
        }
    }

    private final WebSocketPolicy policy;
    private final ExtensionFactory factory;

    public ExtensionTool(WebSocketPolicy policy) {
        this.policy = policy;
        factory = new WebSocketExtensionFactory();
    }

    public Tester newTester(string parameterizedExtension) {
        return new Tester(parameterizedExtension);
    }
}
