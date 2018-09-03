module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;

/**
 * A Data Frame
 */
class DataFrame : WebSocketFrame {
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
    this(Frame basedOn) {
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
    this(Frame basedOn, bool continuation) {
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
