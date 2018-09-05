module hunt.http.codec.websocket.frame.WebSocketFrame;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.common;

import hunt.container;
import hunt.util.string;

/**
 * A Base Frame as seen in <a href="https://tools.ietf.org/html/rfc6455#section-5.2">RFC 6455. Sec 5.2</a>
 * <p>
 * <pre>
 *    0                   1                   2                   3
 *    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 *   +-+-+-+-+-------+-+-------------+-------------------------------+
 *   |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
 *   |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
 *   |N|V|V|V|       |S|             |   (if payload len==126/127)   |
 *   | |1|2|3|       |K|             |                               |
 *   +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
 *   |     Extended payload length continued, if payload len == 127  |
 *   + - - - - - - - - - - - - - - - +-------------------------------+
 *   |                               |Masking-key, if MASK set to 1  |
 *   +-------------------------------+-------------------------------+
 *   | Masking-key (continued)       |          Payload Data         |
 *   +-------------------------------- - - - - - - - - - - - - - - - +
 *   :                     Payload Data continued ...                :
 *   + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
 *   |                     Payload Data continued ...                |
 *   +---------------------------------------------------------------+
 * </pre>
 */
abstract class WebSocketFrame : Frame {

    /**
     * Combined FIN + RSV1 + RSV2 + RSV3 + OpCode byte.
     * <p>
     * <pre>
     *   1000_0000 (0x80) = fin
     *   0100_0000 (0x40) = rsv1
     *   0010_0000 (0x20) = rsv2
     *   0001_0000 (0x10) = rsv3
     *   0000_1111 (0x0F) = opcode
     * </pre>
     */
    protected byte finRsvOp;
    protected bool masked = false;

    protected byte[] mask;
    /**
     * The payload data.
     * <p>
     * It is assumed to always be in FLUSH mode (ready to read) in this object.
     */
    protected ByteBuffer data;

    /**
     * Construct form opcode
     *
     * @param opcode the opcode the frame is based on
     */
    protected this(byte opcode) {
        reset();
        setOpCode(opcode);
    }

    abstract void assertValid();

    void copyHeaders(Frame frame) {
        finRsvOp = 0x00;
        finRsvOp |= frame.isFin() ? 0x80 : 0x00;
        finRsvOp |= frame.isRsv1() ? 0x40 : 0x00;
        finRsvOp |= frame.isRsv2() ? 0x20 : 0x00;
        finRsvOp |= frame.isRsv3() ? 0x10 : 0x00;
        finRsvOp |= frame.getOpCode() & 0x0F;

        masked = frame.isMasked();
        if (masked) {
            mask = frame.getMask();
        } else {
            mask = null;
        }
    }

    protected void copyHeaders(WebSocketFrame copy) {
        finRsvOp = copy.finRsvOp;
        masked = copy.masked;
        mask = null;
        if (copy.mask !is null)
            mask = copy.mask.dup;
    }

    bool equals(Object obj) { return opEquals(obj); }

    override bool opEquals(Object obj) {
        if (this is obj) {
            return true;
        }
        if (obj is null) {
            return false;
        }

        WebSocketFrame other = cast(WebSocketFrame) obj;
        if(other is null) return false;
        
        if (data is null) {
            if (other.data !is null) {
                return false;
            }
        } else if (!data.opEquals(other.data)) {
            return false;
        }
        if (finRsvOp != other.finRsvOp) {
            return false;
        }
        if (mask != other.mask) {
            return false;
        }
        if (masked != other.masked) {
            return false;
        }
        return true;
    }

    override
    byte[] getMask() {
        return mask;
    }

    override
    final byte getOpCode() {
        return cast(byte) (finRsvOp & 0x0F);
    }

    /**
     * Get the payload ByteBuffer. possible null.
     */
    override
    ByteBuffer getPayload() {
        return data;
    }

    string getPayloadAsUTF8() {
        return BufferUtils.toString(getPayload());
    }

    override
    int getPayloadLength() {
        if (data is null) {
            return 0;
        }
        return data.remaining();
    }

    override
    Type getType() {
        return FrameTypeHelper.from(getOpCode());
    }

    size_t hashCode() { return toHash(); }

    override size_t toHash() @trusted nothrow {
        int prime = 31;
        size_t result = 1;
        result = (prime * result) + ((data is null) ? 0 : data.toHash());
        result = (prime * result) + finRsvOp;
        result = (prime * result) + hashOf(mask);
        return result;
    }

    override
    bool hasPayload() {
        return ((data !is null) && data.hasRemaining());
    }

    abstract bool isControlFrame();

    abstract bool isDataFrame();

    override
    bool isFin() {
        return cast(byte) (finRsvOp & 0x80) != 0;
    }

    override
    bool isMasked() {
        return masked;
    }

    override
    bool isRsv1() {
        return cast(byte) (finRsvOp & 0x40) != 0;
    }

    override
    bool isRsv2() {
        return cast(byte) (finRsvOp & 0x20) != 0;
    }

    override
    bool isRsv3() {
        return cast(byte) (finRsvOp & 0x10) != 0;
    }

    void reset() {
        finRsvOp = cast(byte) 0x80; // FIN (!RSV, opcode 0)
        masked = false;
        data = null;
        mask = null;
    }

    WebSocketFrame setFin(bool fin) {
        // set bit 1
        this.finRsvOp = cast(byte) ((finRsvOp & 0x7F) | (fin ? 0x80 : 0x00));
        return this;
    }

    Frame setMask(byte[] maskingKey) {
        this.mask = maskingKey;
        this.masked = (mask !is null);
        return this;
    }

    Frame setMasked(bool mask) {
        this.masked = mask;
        return this;
    }

    protected WebSocketFrame setOpCode(byte op) {
        this.finRsvOp = cast(byte) ((finRsvOp & 0xF0) | (op & 0x0F));
        return this;
    }

    /**
     * Set the data payload.
     * <p>
     * The provided buffer will be used as is, no copying of bytes performed.
     * <p>
     * The provided buffer should be flipped and ready to READ from.
     *
     * @param buf the bytebuffer to set
     * @return the frame itself
     */
    WebSocketFrame setPayload(ByteBuffer buf) {
        data = buf;
        return this;
    }

    WebSocketFrame setRsv1(bool rsv1) {
        // set bit 2
        this.finRsvOp = cast(byte) ((finRsvOp & 0xBF) | (rsv1 ? 0x40 : 0x00));
        return this;
    }

    WebSocketFrame setRsv2(bool rsv2) {
        // set bit 3
        this.finRsvOp = cast(byte) ((finRsvOp & 0xDF) | (rsv2 ? 0x20 : 0x00));
        return this;
    }

    WebSocketFrame setRsv3(bool rsv3) {
        // set bit 4
        this.finRsvOp = cast(byte) ((finRsvOp & 0xEF) | (rsv3 ? 0x10 : 0x00));
        return this;
    }

    override
    string toString() {
        StringBuilder b = new StringBuilder();
        b.append(OpCode.name(cast(byte) (finRsvOp & 0x0F)));
        b.append('[');
        b.append("len=").append(getPayloadLength());
        b.append(",fin=").append((finRsvOp & 0x80) != 0);
        b.append(",rsv=");
        b.append(((finRsvOp & 0x40) != 0) ? '1' : '.');
        b.append(((finRsvOp & 0x20) != 0) ? '1' : '.');
        b.append(((finRsvOp & 0x10) != 0) ? '1' : '.');
        b.append(",masked=").append(masked);
        b.append(']');
        return b.toString();
    }
}
