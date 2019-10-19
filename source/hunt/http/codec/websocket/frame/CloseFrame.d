module hunt.http.codec.websocket.frame.CloseFrame;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.frame.ControlFrame;
import hunt.http.codec.websocket.model.common;

import hunt.text.Common;

class CloseFrame : ControlFrame {
    this() {
        super(OpCode.CLOSE);
    }

    override
    WebSocketFrameType getType() {
        return WebSocketFrameType.CLOSE;
    }

    /**
     * Truncate arbitrary reason into something that will fit into the CloseFrame limits.
     *
     * @param reason the arbitrary reason to possibly truncate.
     * @return the possibly truncated reason string.
     */
    static string truncate(string reason) {
        enum limit = ControlFrame.MAX_CONTROL_PAYLOAD - 2;
        if(reason.length > limit)
            return reason[0..limit];
        else
            return reason;
    }
}
