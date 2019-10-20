module hunt.http.codec.http.model.Protocol;

import hunt.http.HttpStatus;
import hunt.http.HttpHeader;
import hunt.http.HttpMetaData;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;


/**
 * 
 */
enum Protocol {
    NONE, H2, WEB_SOCKET
}

struct ProtocolHelper {

    static Protocol from(HttpRequest request) {
        return getProtocol(request);
    }

    static Protocol from(HttpResponse response) {
        if (response.getStatus() == HttpStatus.SWITCHING_PROTOCOLS_101) {
            return getProtocol(response);
        } else {
            return Protocol.NONE;
        }
    }

    private static Protocol getProtocol(HttpMetaData metaData) {
        if (metaData.getFields().contains(HttpHeader.CONNECTION, "Upgrade")) {
            if (metaData.getFields().contains(HttpHeader.UPGRADE, "h2c")) {
                return Protocol.H2;
            } else if (metaData.getFields().contains(HttpHeader.UPGRADE, "websocket")) {
                return Protocol.WEB_SOCKET;
            } else {
                return Protocol.NONE;
            }
        } else {
            return Protocol.NONE;
        }
    }
}
