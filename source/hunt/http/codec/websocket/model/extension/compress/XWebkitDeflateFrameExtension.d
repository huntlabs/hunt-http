module hunt.http.codec.websocket.model.extension.compress;

/**
 * Implementation of the <a href="https://tools.ietf.org/id/draft-tyoshino-hybi-websocket-perframe-deflate-05.txt">x-webkit-deflate-frame</a> extension seen out
 * in the wild. Using the alternate extension identification
 */
class XWebkitDeflateFrameExtension : DeflateFrameExtension {
    override
    string getName() {
        return "x-webkit-deflate-frame";
    }
}
