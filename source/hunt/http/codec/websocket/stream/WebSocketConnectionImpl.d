module hunt.http.codec.websocket.stream.WebSocketConnectionImpl;

import hunt.http.codec.websocket.decode.Parser;
import hunt.http.codec.websocket.encode;
import hunt.http.codec.websocket.frame;
import hunt.http.codec.websocket.model.CloseInfo;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.stream.ExtensionNegotiator;
import hunt.http.codec.websocket.stream.IOState;

import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpConnection;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;
import hunt.http.HttpOptions;
import hunt.http.HttpVersion;
import hunt.http.WebSocketCommon;
import hunt.http.WebSocketConnection;
import hunt.http.WebSocketPolicy;

import hunt.http.Util;

import hunt.collection;
import hunt.concurrency.FuturePromise;
import hunt.concurrency.Delayed;
import hunt.Exceptions;
import hunt.Functions;
import hunt.logging;
import hunt.net.AbstractConnection;
import hunt.net.Connection;
import hunt.util.Common;
import hunt.util.Runnable;

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
        // ioState.onOpened();

        //dfmt off
        extensionNegotiator.setNextOutgoingFrames(
            new class OutgoingFrames { 

                void outgoingFrame(WebSocketFrame frame, Callback callback) {

                    AbstractWebSocketFrame webSocketFrame = cast(AbstractWebSocketFrame) frame;
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

                    if (frame.getType() == WebSocketFrameType.CLOSE) {
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

        setNextIncomingFrames(nextIncomingFrames);

        if (this.policy.getBehavior() == WebSocketBehavior.CLIENT) {
            executor = CommonUtil.scheduler();
            executor.setRemoveOnCancelPolicy(true);
            ScheduledFuture!(void) pingFuture = executor.scheduleWithFixedDelay(new class Runnable {
                    void run() {
                        PingFrame pingFrame = new PingFrame();

                        outgoingFrame(pingFrame, new class NoopCallback {
                            override void succeeded() {
                                version(HUNT_HTTP_DEBUG) infof("The websocket connection %s sent ping frame success", getId());
                            }

                            override void failed(Exception x) {
                                debug warningf("the websocket connection %s sends ping frame failure. %s", getId(), x.msg);
                                version(HUNT_HTTP_DEBUG)  warning(x);
                            }
                        });
                    }
                }, 
                msecs(config.getWebsocketPingInterval()), 
                msecs(config.getWebsocketPingInterval()));

            onClose( (c) {
                version(HUNT_HTTP_DEBUG) 
                infof("Cancelling the ping task on connection %d with %s", this.getId(), this.getRemoteAddress());
                pingFuture.cancel(false); 
            });
        }        

//dfmt on        
    }

    override WebSocketConnection onClose(Action1!(HttpConnection) handler) {
        super.onClose(handler);
        return this;
    }

    override WebSocketConnection onException(Action2!(HttpConnection, Exception) handler) {
        // return connectionEvent.onException(exceptionListener);
        super.onException(handler);
        return this;
    }

    override void notifyClose() {
        version(HUNT_DEBUG) tracef("closing, state: %s", ioState.getConnectionState());
        ioState.onDisconnected();
        // connectionEvent.notifyClose();
        super.notifyClose();
    }

    override void notifyException(Exception t) {
        version(HUNT_DEBUG) warningf("exception, state: %s, error: %s", 
            ioState.getConnectionState(), t.msg);
        ioState.onReadFailure(t);
        // connectionEvent.notifyException(t);
        super.notifyException(t);
    }

    bool isConnected() {
        if(ioState !is null) {
            WebSocketConnectionState state = ioState.getConnectionState();
            version(HUNT_HTTP_DEBUG) tracef("io state: %s", state) ;
            return state == WebSocketConnectionState.CONNECTED || state == WebSocketConnectionState.OPEN;
        }
        return false;
    }

    override IOState getIOState() {
        return ioState;
    }

    override WebSocketPolicy getPolicy() {
        return policy;
    }

    void outgoingFrame(WebSocketFrame frame, Callback callback) {
        extensionNegotiator.getOutgoingFrames().outgoingFrame(frame, callback);
    }

    void setNextIncomingFrames(IncomingFrames nextIncomingFrames) {
        if (nextIncomingFrames !is null) {
            extensionNegotiator.setNextIncomingFrames(nextIncomingFrames);
            HttpMetaData metaData;
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

    override void incomingFrame(WebSocketFrame frame) {
        switch (frame.getType()) {
        case WebSocketFrameType.PING: {
                PongFrame pongFrame = new PongFrame();
                outgoingFrame(pongFrame, Callback.NOOP);
            }
            break;

        case WebSocketFrameType.CLOSE: {
                CloseFrame closeFrame = cast(CloseFrame) frame;
                CloseInfo closeInfo = new CloseInfo(closeFrame.getPayload(), false);
                ioState.onCloseRemote(closeInfo);
                this.close();
            }
            break;

        case WebSocketFrameType.PONG: {
                infof("The websocket connection %s received pong frame", getId());
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

    override FuturePromise!(bool) sendText(string text) {
        TextFrame textFrame = new TextFrame();
        textFrame.setPayload(text);
        FuturePromise!(bool) future = new FuturePromise!bool();
        //dfmt off        
        outgoingFrame(textFrame, 
            new class NoopCallback {
            override void succeeded() {
                future.succeeded(true);
            }

            override void failed(Exception x) {
                future.failed(x);
            }
        });
//dfmt on        
        return future;
    }

    override FuturePromise!(bool) sendData(byte[] data) {
        return _sendData(data);
    }

    override FuturePromise!(bool) sendData(ByteBuffer data) {
        return _sendData(data);
    }

    private FuturePromise!(bool) _sendData(T)(T data) {
        BinaryFrame binaryFrame = new BinaryFrame();
        binaryFrame.setPayload(data);
        FuturePromise!(bool) future = new FuturePromise!bool();
        //dfmt off        
        outgoingFrame(binaryFrame, 
            new class NoopCallback {
            override void succeeded() {
                future.succeeded(true);
            }

            override void failed(Exception x) {
                future.failed(x);
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

    override void setAttribute(string key, Object value) {
        super.setAttribute(key, value);
    }
    
    override Object getAttribute(string key) {
        return super.getAttribute(key);
    }
    
    override Object removeAttribute(string key) {
        return super.removeAttribute(key);
    }    
    
    override bool containsAttribute(string key) {
        return super.containsAttribute(key);
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
