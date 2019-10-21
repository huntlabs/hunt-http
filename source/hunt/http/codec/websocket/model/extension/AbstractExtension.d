module hunt.http.codec.websocket.model.extension.AbstractExtension;

import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.ExtensionConfig;

import hunt.http.WebSocketConnection;
import hunt.http.WebSocketFrame;
import hunt.http.WebSocketPolicy;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.util.Common;
import hunt.util.Lifecycle;

import std.format;

/**
*/
abstract class AbstractExtension : AbstractLifecycle , Extension {
    
    private WebSocketPolicy policy;
    private ExtensionConfig config;
    private OutgoingFrames nextOutgoing;
    private IncomingFrames nextIncoming;

    this() {
    }

    void dump(Appendable ot, string indent) {
        // incoming
        dumpWithHeading(ot, indent, "incoming", cast(Object)this.nextIncoming);
        dumpWithHeading(ot, indent, "outgoing", cast(Object)this.nextOutgoing);
    }

    protected void dumpWithHeading(Appendable ot, string indent, string heading, Object bean) {
        ot.append(indent).append(" ~- ");
        ot.append(heading).append(" : ");
        ot.append(bean.toString());
    }

    override
    ExtensionConfig getConfig() {
        return config;
    }

    override
    string getName() {
        return config.getName();
    }

    IncomingFrames getNextIncoming() {
        return nextIncoming;
    }

    OutgoingFrames getNextOutgoing() {
        return nextOutgoing;
    }

    WebSocketPolicy getPolicy() {
        return policy;
    }

    void incomingError(Exception e) {
        nextIncomingError(e);
    }

    /**
     * Used to indicate that the extension makes use of the RSV1 bit of the base websocket framing.
     * <p>
     * This is used to adjust validation during parsing, as well as a checkpoint against 2 or more extensions all simultaneously claiming ownership of RSV1.
     *
     * @return true if extension uses RSV1 for its own purposes.
     */
    override
    bool isRsv1User() {
        return false;
    }

    /**
     * Used to indicate that the extension makes use of the RSV2 bit of the base websocket framing.
     * <p>
     * This is used to adjust validation during parsing, as well as a checkpoint against 2 or more extensions all simultaneously claiming ownership of RSV2.
     *
     * @return true if extension uses RSV2 for its own purposes.
     */
    override
    bool isRsv2User() {
        return false;
    }

    /**
     * Used to indicate that the extension makes use of the RSV3 bit of the base websocket framing.
     * <p>
     * This is used to adjust validation during parsing, as well as a checkpoint against 2 or more extensions all simultaneously claiming ownership of RSV3.
     *
     * @return true if extension uses RSV3 for its own purposes.
     */
    override
    bool isRsv3User() {
        return false;
    }

    protected void nextIncomingError(Exception e) {
        this.nextIncoming.incomingError(e);
    }

    protected void nextIncomingFrame(WebSocketFrame frame) {
        tracef("nextIncomingFrame(%s)", frame);
        this.nextIncoming.incomingFrame(frame);
    }

    protected void nextOutgoingFrame(WebSocketFrame frame, Callback callback) {
        tracef("nextOutgoingFrame(%s)", frame);
        this.nextOutgoing.outgoingFrame(frame, callback);
    }

    void setConfig(ExtensionConfig config) {
        this.config = config;
    }

    override
    void setNextIncomingFrames(IncomingFrames nextIncoming) {
        this.nextIncoming = nextIncoming;
    }

    override
    void setNextOutgoingFrames(OutgoingFrames nextOutgoing) {
        this.nextOutgoing = nextOutgoing;
    }

    void setPolicy(WebSocketPolicy policy) {
        this.policy = policy;
    }

    override
    string toString() {
        return format("%s[%s]", typeid(this).name, config.getParameterizedName());
    }
}
