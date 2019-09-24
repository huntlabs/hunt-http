module hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.MetaData;
import hunt.http.HttpOptions;
import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.encode;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.common;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.http.codec.websocket.stream.ExtensionNegotiator;
import hunt.http.codec.websocket.stream.IOState;
import hunt.http.codec.websocket.stream.WebSocketConnection;
import hunt.http.codec.websocket.stream.WebSocketPolicy;

import hunt.http.AbstractHttpConnection;
import hunt.http.HttpVersion;

import hunt.net.AbstractConnection;

import hunt.http.HttpConnectionType;
// import hunt.net.secure.SecureSession;
import hunt.net.Connection;

import hunt.collection;
import hunt.Functions;
import hunt.logging;
import hunt.concurrency.CompletableFuture;
import hunt.Exceptions;
import hunt.util.Common;

import core.time;

import std.random;
import std.socket;
import std.array;

/**
 * 
 */
class WebSocketConnectionImpl : AbstractHttpConnection, WebSocketConnection, IncomingFrames {

    // protected ConnectionEvent!(WebSocketConnection) connectionEvent;
    protected Parser parser;
    protected Generator generator;
    protected WebSocketPolicy policy;
    protected HttpRequest upgradeRequest;
    protected HttpResponse upgradeResponse;
    protected IOState ioState;
    protected HttpOptions config;
    protected ExtensionNegotiator extensionNegotiator;

    this(Connection tcpSession, IncomingFrames nextIncomingFrames, WebSocketPolicy policy,
            HttpRequest upgradeRequest, HttpResponse upgradeResponse,
            HttpOptions config) {
        super(tcpSession, HttpVersion.HTTP_1_1);

        extensionNegotiator = new ExtensionNegotiator();
        // connectionEvent = new ConnectionEvent!(WebSocketConnection)(this);
        parser = new Parser(policy);
        parser.setIncomingFramesHandler(this);
        generator = new Generator(policy);
        this.policy = policy;
        this.upgradeRequest = upgradeRequest;
        this.upgradeResponse = upgradeResponse;
        this.config = config;
        ioState = new IOState();
        ioState.onOpened();

        //dfmt off
        extensionNegotiator.setNextOutgoingFrames(
            new class OutgoingFrames { 

                void outgoingFrame(Frame frame, Callback callback) {

                    WebSocketFrame webSocketFrame = cast(WebSocketFrame) frame;
                    if (policy.getBehavior() == WebSocketBehavior.CLIENT && webSocketFrame !is null) {
                        if (!webSocketFrame.isMasked()) {
                            webSocketFrame.setMask(generateMask());
                        }
                    }
                    ByteBuffer buf = BufferUtils.allocate(Generator.MAX_HEADER_LENGTH + frame.getPayloadLength());
                    generator.generateWholeFrame(frame, buf);
                    BufferUtils.flipToFlush(buf, 0);

                    // error(buf.toString());
                    
                    // tcpSession.encode(new ByteBufferOutputEntry(callback, buf));
                    try {
                        tcpSession.encode(buf);
                        callback.succeeded();
                    } catch(Exception ex ){
                        warning(ex);
                        callback.failed(ex);
                    }

                    if (frame.getType() == Frame.Type.CLOSE) {
                        CloseFrame closeFrame = cast(CloseFrame) frame;
                        if(closeFrame !is null) {
                            CloseInfo closeInfo = new CloseInfo(closeFrame.getPayload(), false);
                            getIOState().onCloseLocal(closeInfo);
                            this.outer.close();
                        }
                    }
                }
            }
        );
//dfmt on
        setNextIncomingFrames(nextIncomingFrames);

        if (this.policy.getBehavior() == WebSocketBehavior.CLIENT) {
// TODO: Tasks pending completion -@zxp at 8/6/2019, 5:48:02 PM
// 
            implementationMissing(false);

            // Scheduler.Future pingFuture = scheduler.scheduleAtFixedRate(() {
            //     PingFrame pingFrame = new PingFrame();
            //     outgoingFrame(pingFrame, new class NoopCallback {
            //         void succeeded() {
            //             info("The websocket connection %s sent ping frame success", getId());
            //         }

            //         void failed(Exception x) {
            //             log.warn("the websocket connection %s sends ping frame failure. %s", getId(), x.getMessage());
            //         }
            //     });
            // }, config.getWebsocketPingInterval(), config.getWebsocketPingInterval(), TimeUnit.MILLISECONDS);
            // onClose(c -> pingFuture.cancel());
        }
    }

    // override WebSocketConnection onClose(Action1!(WebSocketConnection) closedListener) {
    //     return connectionEvent.onClose(closedListener);
    // }

    // override WebSocketConnection onException(Action2!(WebSocketConnection,
    //         Exception) exceptionListener) {
    //     return connectionEvent.onException(exceptionListener);
    // }

    // override void notifyClose() {
    //     version(HUNT_DEBUG) tracef("closing, state: %s", ioState.getConnectionState());
    //     ioState.onDisconnected();
    //     // connectionEvent.notifyClose();
    //     super.notifyClose.onClosed();
    // }

    // override void notifyException(Exception t) {
    //     version(HUNT_DEBUG) warningf("exception, state: %s, error: %s", 
    //         ioState.getConnectionState(), t.msg);
    //     ioState.onReadFailure(t);
    //     // connectionEvent.notifyException(t);
    //     super.notifyException(t);
    // }

    override IOState getIOState() {
        return ioState;
    }

    override WebSocketPolicy getPolicy() {
        return policy;
    }

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
            Extension[] extensions = extensionNegotiator.parse(metaData);
            if (!extensions.empty()) {
                generator.configureFromExtensions(extensions);
                parser.configureFromExtensions(extensions);

                foreach (Extension e; extensions) {
                    AbstractExtension ae = cast(AbstractExtension) e;
                    if (ae is null)
                        continue;
                    ae.setPolicy(policy);
                }
                // auto r = extensions.filter!(e => instanceof!(AbstractExtension)(e))
                //     .map!(e => cast(AbstractExtension)e);
                // extensions.stream().filter(e -> e instanceof AbstractExtension)
                //           .map(e -> (AbstractExtension) e)
                //           .forEach(e -> e.setPolicy(policy));
            }
        }
    }

    void incomingError(Exception t) {
        // Optional.ofNullable(extensionNegotiator.getIncomingFrames()).ifPresent(e -> e.incomingError(t));
        IncomingFrames frames = extensionNegotiator.getIncomingFrames();
        if (frames !is null)
            frames.incomingError(t);
    }

    override void incomingFrame(Frame frame) {
        switch (frame.getType()) {
        case FrameType.PING: {
                PongFrame pongFrame = new PongFrame();
                outgoingFrame(pongFrame, Callback.NOOP);
            }
            break;

        case FrameType.CLOSE: {
                CloseFrame closeFrame = cast(CloseFrame) frame;
                CloseInfo closeInfo = new CloseInfo(closeFrame.getPayload(), false);
                ioState.onCloseRemote(closeInfo);
                this.close();
            }
            break;

        case FrameType.PONG: {
                info("The websocket connection %s received pong frame", getId());
            }
            break;

        default:
            break;
        }

        IncomingFrames e = extensionNegotiator.getIncomingFrames();
        if (e !is null) {
            version(HUNT_HTTP_DEBUG_MORE) {
                trace(BufferUtils.toDetailString(frame.getPayload()));
            }
            e.incomingFrame(frame);
        }
    }

    // override bool isSecured() {
    //     return secureSession !is null;
    // }

    override HttpConnectionType getConnectionType() {
        return HttpConnectionType.WEB_SOCKET;
    }

    override byte[] generateMask() {
        byte[] mask = new byte[4];
        // ThreadLocalRandom.current().nextBytes(mask);
        foreach (size_t i; 0 .. mask.length)
            mask[i] = uniform(byte.min, byte.max);
        return mask;
    }

    override CompletableFuture!(bool) sendText(string text) {
        TextFrame textFrame = new TextFrame();
        textFrame.setPayload(text);
        CompletableFuture!(bool) future = new CompletableFuture!bool();
        //dfmt off        
        outgoingFrame(textFrame, 
            new class NoopCallback {
            override void succeeded() {
                future.complete(true);
            }

            override void failed(Exception x) {
                future.completeExceptionally(x);
            }
        });
//dfmt on        
        return future;
    }

    override CompletableFuture!(bool) sendData(byte[] data) {
        return _sendData(data);
    }

    override CompletableFuture!(bool) sendData(ByteBuffer data) {
        return _sendData(data);
    }

    private CompletableFuture!(bool) _sendData(T)(T data) {
        BinaryFrame binaryFrame = new BinaryFrame();
        binaryFrame.setPayload(data);
        CompletableFuture!(bool) future = new CompletableFuture!bool();
        //dfmt off        
        outgoingFrame(binaryFrame, 
            new class NoopCallback {
            override void succeeded() {
                future.complete(true);
            }

            override void failed(Exception x) {
                future.completeExceptionally(x);
            }
        });
//dfmt on          
        return future;
    }

    override HttpRequest getUpgradeRequest() {
        return upgradeRequest;
    }

    override HttpResponse getUpgradeResponse() {
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

    // override Object getAttachment() {
    //     return super.getAttachment();
    // }

    // override void setAttachment(Object attachment) {
    //     super.setAttachment(attachment);
    // }

    override int getId() {
        return super.getId();
    }

    override Connection getTcpConnection() {
        return super.getTcpConnection();
    }
    
    override Address getLocalAddress() {
        return  super.getLocalAddress();
    }

    override Address getRemoteAddress() {
        return super.getRemoteAddress();
    }

    override HttpVersion getHttpVersion() {
        return super.getHttpVersion();
    }

// version (HUNT_METRIC) {
//     override long getOpenTime() {
//         return super.getOpenTime();
//     }

//     override long getCloseTime() {
//         return super.getCloseTime();
//     }

//     override long getDuration() {
//         return super.getDuration();
//     }

//     override long getLastReadTime() {
//         return super.getLastReadTime();
//     }

//     override long getLastWrittenTime() {
//         return super.getLastWrittenTime();
//     }

//     override long getLastActiveTime() {
//         return super.getLastActiveTime();
//     }

//     override long getReadBytes() {
//         return super.getReadBytes();
//     }

//     override long getWrittenBytes() {
//         return super.getWrittenBytes();
//     }

//     override long getIdleTimeout() {
//         return super.getIdleTimeout();
//     }
// }

//     override Duration getMaxIdleTimeout() {
//         return super.getMaxIdleTimeout();
//     }

//     override bool isConnected() {
//         return super.isConnected();
//     }

//     override bool isClosing() {
//         return super.isClosing();
//     }

//     override Address getLocalAddress() {
//         return super.getLocalAddress();
//     }

//     override Address getRemoteAddress() {
//         return super.getRemoteAddress();
//     }
}
