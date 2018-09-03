module hunt.http.codec.websocket.frame;

import hunt.http.codec.websocket.model.OpCode;
import hunt.http.utils.StringUtils;

class CloseFrame : ControlFrame {
    this() {
        super(OpCode.CLOSE);
    }

    override
    Type getType() {
        return Type.CLOSE;
    }

    /**
     * Truncate arbitrary reason into something that will fit into the CloseFrame limits.
     *
     * @param reason the arbitrary reason to possibly truncate.
     * @return the possibly truncated reason string.
     */
    static string truncate(string reason) {
        return StringUtils.truncate(reason, (ControlFrame.MAX_CONTROL_PAYLOAD - 2));
    }
}
