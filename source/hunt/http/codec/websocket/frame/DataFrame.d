module hunt.http.codec.websocket.frame.DataFrame;

import hunt.http.codec.websocket.frame.AbstractWebSocketFrame;
import hunt.http.WebSocketCommon;
import hunt.http.WebSocketFrame;

/**
 * A Data Frame
 */
class DataFrame : AbstractWebSocketFrame {
    protected this(byte opcode) {
        super(opcode);
    }

    /**
     * Construct new DataFrame based on headers of provided frame.
     * <p>
     * Useful for when working in extensions and a new frame needs to be created.
     *
     * @param basedOn the frame this one is based on
     */
    this(WebSocketFrame basedOn) {
        this(basedOn, false);
    }

    /**
     * Construct new DataFrame based on headers of provided frame, overriding for continuations if needed.
     * <p>
     * Useful for when working in extensions and a new frame needs to be created.
     *
     * @param basedOn      the frame this one is based on
     * @param continuation true if this is a continuation frame
     */
    this(WebSocketFrame basedOn, bool continuation) {
        super(basedOn.getOpCode());
        copyHeaders(basedOn);
        if (continuation) {
            setOpCode(OpCode.CONTINUATION);
        }
    }

    override
    void assertValid() {
        /* no extra validation for data frames (yet) here */
    }

    override
    bool isControlFrame() {
        return false;
    }

    override
    bool isDataFrame() {
        return true;
    }

    /**
     * Set the data frame to continuation mode
     */
    void setIsContinuation() {
        setOpCode(OpCode.CONTINUATION);
    }
}
