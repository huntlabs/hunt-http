module test.codec.websocket.model.extension.compress;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.lang.common;
import test.codec.websocket.utils.Hex;

import hunt.container.ArrayList;
import hunt.container.List;

public class CapturedHexPayloads : OutgoingFrames {
    private List<string> captured = new ArrayList<>();

    override
    public void outgoingFrame(Frame frame, Callback callback) {
        string hexPayload = Hex.asHex(frame.getPayload());
        captured.add(hexPayload);
        if (callback != null) {
            callback.succeeded();
        }
    }

    public List<string> getCaptured() {
        return captured;
    }
}
