module hunt.http.codec.websocket.model.extension;

import hunt.http.codec.websocket.exception.WebSocketException;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.utils.StringUtils;

class WebSocketExtensionFactory : ExtensionFactory {

    override
    Extension newInstance(ExtensionConfig config) {
        if (config == null) {
            return null;
        }

        string name = config.getName();
        if (!StringUtils.hasText(name)) {
            return null;
        }

        Class<? : Extension> extClass = getExtension(name);
        if (extClass == null) {
            return null;
        }

        try {
            return extClass.newInstance();
        } catch (InstantiationException | IllegalAccessException e) {
            throw new WebSocketException("Cannot instantiate extension: " + extClass, e);
        }
    }
}
