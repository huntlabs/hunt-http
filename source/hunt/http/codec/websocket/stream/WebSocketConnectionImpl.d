module hunt.http.codec.websocket.stream.impl;

import hunt.http.codec.common.AbstractConnection;
import hunt.http.codec.common.ConnectionEvent;
import hunt.http.codec.common.ConnectionType;
import hunt.http.codec.http2.model.HttpHeader;
import hunt.http.codec.http2.model.MetaData;
import hunt.http.codec.http2.stream.HTTP2Configuration;
import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.encode.Generator;
import hunt.http.codec.websocket.frame.*;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.model.WebSocketBehavior;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.stream.ExtensionNegotiator;
import hunt.http.codec.websocket.stream.IOState;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;
import hunt.net.ByteBufferOutputEntry;
import hunt.net.SecureSession;
import hunt.net.Session;
import hunt.util.functional;
import hunt.http.utils.concurrent.Scheduler;
import hunt.http.utils.function.Action1;
import hunt.http.utils.function.Action2;
import hunt.http.utils.io.BufferUtils;

import hunt.container.ByteBuffer;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;

/**
 * 
 */
class WebSocketConnectionImpl : AbstractConnection , WebSocketConnection, IncomingFrames {

    protected final ConnectionEvent<WebSocketConnection> connectionEvent;
    protected final Parser parser;
    protected final Generator generator;
    protected final WebSocketPolicy policy;
    protected final MetaData.Request upgradeRequest;
    protected final MetaData.Response upgradeResponse;
    protected IOState ioState;
    protected final HTTP2Configuration config;
    protected final ExtensionNegotiator extensionNegotiator = new ExtensionNegotiator();

    this(SecureSession secureSession, Session tcpSession,
                                   IncomingFrames nextIncomingFrames, WebSocketPolicy policy,
                                   MetaData.Request upgradeRequest, MetaData.Response upgradeResponse,
                                   HTTP2Configuration config) {
        super(secureSession, tcpSession);

        connectionEvent = new ConnectionEvent<>(this);
        parser = new Parser(policy);
        parser.setIncomingFramesHandler(this);
        generator = new Generator(policy);
        this.policy = policy;
        this.upgradeRequest = upgradeRequest;
        this.upgradeResponse = upgradeResponse;
        this.config = config;
        ioState = new IOState();
        ioState.onOpened();

        extensionNegotiator.setNextOutgoingFrames((frame, callback) -> {
            if (policy.getBehavior() == WebSocketBehavior.CLIENT && frame instanceof WebSocketFrame) {
                WebSocketFrame webSocketFrame = (WebSocketFrame) frame;
                if (!webSocketFrame.isMasked()) {
                    webSocketFrame.setMask(generateMask());
                }
            }
            ByteBuffer buf = ByteBuffer.allocate(Generator.MAX_HEADER_LENGTH + frame.getPayloadLength());
            generator.generateWholeFrame(frame, buf);
            BufferUtils.flipToFlush(buf, 0);
            tcpSession.encode(new ByteBufferOutputEntry(callback, buf));
            if (frame.getType() == Frame.Type.CLOSE && frame instanceof CloseFrame) {
                CloseFrame closeFrame = (CloseFrame) frame;
                CloseInfo closeInfo = new CloseInfo(closeFrame.getPayload(), false);
                getIOState().onCloseLocal(closeInfo);
                WebSocketConnectionImpl.this.close();
            }
        });

        setNextIncomingFrames(nextIncomingFrames);

        if (this.policy.getBehavior() == WebSocketBehavior.CLIENT) {
            Scheduler.Future pingFuture = scheduler.scheduleAtFixedRate(() -> {
                PingFrame pingFrame = new PingFrame();
                outgoingFrame(pingFrame, new Callback() {
                    void succeeded() {
                        info("The websocket connection %s sent ping frame success", getSessionId());
                    }

                    void failed(Throwable x) {
                        log.warn("the websocket connection %s sends ping frame failure. %s", getSessionId(), x.getMessage());
                    }
                });
            }, config.getWebsocketPingInterval(), config.getWebsocketPingInterval(), TimeUnit.MILLISECONDS);
            onClose(c -> pingFuture.cancel());
        }

    }

    override
    WebSocketConnection onClose(Action1<WebSocketConnection> closedListener) {
        return connectionEvent.onClose(closedListener);
    }

    override
    WebSocketConnection onException(Action2<WebSocketConnection, Throwable> exceptionListener) {
        return connectionEvent.onException(exceptionListener);
    }

    void notifyClose() {
        connectionEvent.notifyClose();
    }

    void notifyException(Throwable t) {
        connectionEvent.notifyException(t);
    }

    override
    IOState getIOState() {
        return ioState;
    }

    override
    WebSocketPolicy getPolicy() {
        return policy;
    }

    override
    void outgoingFrame(Frame frame, Callback callback) {
        extensionNegotiator.getOutgoingFrames().outgoingFrame(frame, callback);
    }

    void setNextIncomingFrames(IncomingFrames nextIncomingFrames) {
        if (nextIncomingFrames !is null) {
            extensionNegotiator.setNextIncomingFrames(nextIncomingFrames);
            MetaData metaData;
            if (upgradeResponse.getFields().contains(HttpHeader.SEC_WEBSOCKET_EXTENSIONS)) {
                metaData = upgradeResponse;
            } else {
                metaData = upgradeRequest;
            }
            List<Extension> extensions = extensionNegotiator.parse(metaData);
            if (!extensions.isEmpty()) {
                generator.configureFromExtensions(extensions);
                parser.configureFromExtensions(extensions);
                extensions.stream().filter(e -> e instanceof AbstractExtension)
                          .map(e -> (AbstractExtension) e)
                          .forEach(e -> e.setPolicy(policy));
            }
        }
    }

    override
    void incomingError(Throwable t) {
        Optional.ofNullable(extensionNegotiator.getIncomingFrames()).ifPresent(e -> e.incomingError(t));
    }

    override
    void incomingFrame(Frame frame) {
        switch (frame.getType()) {
            case PING: {
                PongFrame pongFrame = new PongFrame();
                outgoingFrame(pongFrame, Callback.NOOP);
            }
            break;
            case CLOSE: {
                CloseFrame closeFrame = (CloseFrame) frame;
                CloseInfo closeInfo = new CloseInfo(closeFrame.getPayload(), false);
                ioState.onCloseRemote(closeInfo);
                this.close();
            }
            break;
            case PONG: {
                info("The websocket connection %s received pong frame", getSessionId());
            }
            break;
        }
        Optional.ofNullable(extensionNegotiator.getIncomingFrames()).ifPresent(e -> e.incomingFrame(frame));
    }

    override
    bool isEncrypted() {
        return secureSession !is null;
    }

    override
    ConnectionType getConnectionType() {
        return ConnectionType.WEB_SOCKET;
    }

    override
    byte[] generateMask() {
        byte[] mask = new byte[4];
        ThreadLocalRandom.current().nextBytes(mask);
        return mask;
    }

    override
    CompletableFuture<Boolean> sendText(string text) {
        TextFrame textFrame = new TextFrame();
        textFrame.setPayload(text);
        CompletableFuture<Boolean> future = new CompletableFuture<>();
        outgoingFrame(textFrame, new Callback() {
            override
            void succeeded() {
                future.complete(true);
            }

            override
            void failed(Throwable x) {
                future.completeExceptionally(x);
            }
        });
        return future;
    }

    override
    CompletableFuture<Boolean> sendData(byte[] data) {
        return _sendData(data, BinaryFrame::setPayload);
    }

    override
    CompletableFuture<Boolean> sendData(ByteBuffer data) {
        return _sendData(data, BinaryFrame::setPayload);
    }

    private <T> CompletableFuture<Boolean> _sendData(T data, Action2<BinaryFrame, T> setData) {
        BinaryFrame binaryFrame = new BinaryFrame();
        setData.call(binaryFrame, data);
        CompletableFuture<Boolean> future = new CompletableFuture<>();
        outgoingFrame(binaryFrame, new Callback() {
            override
            void succeeded() {
                future.complete(true);
            }

            override
            void failed(Throwable x) {
                future.completeExceptionally(x);
            }
        });
        return future;
    }

    override
    MetaData.Request getUpgradeRequest() {
        return upgradeRequest;
    }

    override
    MetaData.Response getUpgradeResponse() {
        return upgradeResponse;
    }

    ExtensionNegotiator getExtensionNegotiator() {
        return extensionNegotiator;
    }

    Parser getParser() {
        return parser;
    }

    Generator getGenerator() {
        return generator;
    }
}
