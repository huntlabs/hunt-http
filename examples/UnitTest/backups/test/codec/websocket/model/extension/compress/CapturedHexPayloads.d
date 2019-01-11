module test.codec.websocket.model.extension.compress;

import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.util.Common;
import test.codec.websocket.utils.Hex;

import hunt.collection.ArrayList;
import hunt.collection.List;

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
