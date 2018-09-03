module hunt.http.codec.websocket.stream;

import hunt.http.codec.http2.model.HttpHeader;
import hunt.http.codec.http2.model.MetaData;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.model.extension.ExtensionFactory;
import hunt.http.codec.websocket.model.extension.WebSocketExtensionFactory;
import hunt.http.utils.Assert;
import hunt.http.utils.CollectionUtils;

import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

import hunt.http.codec.websocket.model.ExtensionConfig.parseEnum;

/**
 * 
 */
class ExtensionNegotiator {

    private ExtensionFactory factory;
    private IncomingFrames nextIncomingFrames;
    private OutgoingFrames nextOutgoingFrames;
    private IncomingFrames incomingFrames;
    private OutgoingFrames outgoingFrames;

    ExtensionNegotiator() {
        this(new WebSocketExtensionFactory());
    }

    ExtensionNegotiator(ExtensionFactory factory) {
        this.factory = factory;
    }

    ExtensionFactory getFactory() {
        return factory;
    }

    void setFactory(ExtensionFactory factory) {
        this.factory = factory;
    }

    List<ExtensionConfig> negotiate(MetaData metaData) {
        return parseEnum(metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString()))
                .stream().filter(c -> factory.isAvailable(c.getName()))
                .collect(Collectors.toList());
    }

    List<Extension> parse(MetaData metaData) {
        Assert.notNull(nextIncomingFrames, "The next incoming frames MUST be not null");
        Assert.notNull(nextOutgoingFrames, "The next outgoing frames MUST be not null");

        List<Extension> extensions = _parse(metaData);
        if (!CollectionUtils.isEmpty(extensions)) {
            for (int i = 0; i < extensions.size(); i++) {
                int next = i + 1;
                if (next < extensions.size() - 1) {
                    extensions.get(i).setNextIncomingFrames(extensions.get(next));
                } else {
                    extensions.get(i).setNextIncomingFrames(nextIncomingFrames);
                }
            }
            incomingFrames = extensions.get(0);

            for (int i = extensions.size() - 1; i >= 0; i--) {
                int next = i - 1;
                if (next > 0) {
                    extensions.get(i).setNextOutgoingFrames(extensions.get(next));
                } else {
                    extensions.get(i).setNextOutgoingFrames(nextOutgoingFrames);
                }
            }
            outgoingFrames = extensions.get(extensions.size() - 1);
            return extensions;
        } else {
            incomingFrames = nextIncomingFrames;
            outgoingFrames = nextOutgoingFrames;
            return Collections.emptyList();
        }
    }

    protected List<Extension> _parse(MetaData metaData) {
        return parseEnum(metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString()))
                .stream().filter(c -> factory.isAvailable(c.getName()))
                .map(c -> {
                    Extension e = factory.newInstance(c);
                    if (e instanceof AbstractExtension) {
                        AbstractExtension abstractExtension = (AbstractExtension) e;
                        abstractExtension.setConfig(c);
                    }
                    return e;
                })
                .collect(Collectors.toList());
    }

    IncomingFrames getNextIncomingFrames() {
        return nextIncomingFrames;
    }

    void setNextIncomingFrames(IncomingFrames nextIncomingFrames) {
        this.nextIncomingFrames = nextIncomingFrames;
    }

    OutgoingFrames getNextOutgoingFrames() {
        return nextOutgoingFrames;
    }

    void setNextOutgoingFrames(OutgoingFrames nextOutgoingFrames) {
        this.nextOutgoingFrames = nextOutgoingFrames;
    }

    IncomingFrames getIncomingFrames() {
        return incomingFrames;
    }

    OutgoingFrames getOutgoingFrames() {
        return outgoingFrames;
    }

}
