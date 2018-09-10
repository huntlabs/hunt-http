module hunt.http.codec.websocket.stream.ExtensionNegotiator;

import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.MetaData;
import hunt.http.codec.websocket.model.Extension;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.IncomingFrames;
import hunt.http.codec.websocket.model.OutgoingFrames;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.http.codec.websocket.model.extension.ExtensionFactory;
import hunt.http.codec.websocket.model.extension.WebSocketExtensionFactory;

import hunt.container;

import hunt.http.codec.websocket.model.ExtensionConfig;

import hunt.container;
import hunt.util.exception;

import std.algorithm;
import std.array;
import std.container.array;
import std.range;

/**
 * 
 */
class ExtensionNegotiator {

    private ExtensionFactory factory;
    private IncomingFrames nextIncomingFrames;
    private OutgoingFrames nextOutgoingFrames;
    private IncomingFrames incomingFrames;
    private OutgoingFrames outgoingFrames;

    this() {
        this(new WebSocketExtensionFactory());
    }

    this(ExtensionFactory factory) {
        this.factory = factory;
    }

    ExtensionFactory getFactory() {
        return factory;
    }

    void setFactory(ExtensionFactory factory) {
        this.factory = factory;
    }

    ExtensionConfig[] negotiate(MetaData metaData) {
        InputRange!string fieldValues = metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString());

        Array!(ExtensionConfig) configList = ExtensionConfig.parseEnum(fieldValues);
        auto r = configList[].filter!(c => factory.isAvailable(c.getName()));

        return r.array;
        // return parseEnum(metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString()))
        //         .stream().filter(c -> factory.isAvailable(c.getName()))
        //         .collect(Collectors.toList());
    }

    Extension[] parse(MetaData metaData) {
        assert(nextIncomingFrames !is null, "The next incoming frames MUST be not null");
        assert(nextOutgoingFrames !is null, "The next outgoing frames MUST be not null");

        Extension[] extensions = _parse(metaData);
        if (!extensions.empty) {
            size_t len = extensions.length;
            for (size_t i = 0; i < len; i++) {
                size_t next = i + 1;
                if (next < len - 1) {
                    extensions[i].setNextIncomingFrames(extensions[next]);
                } else {
                    extensions[i].setNextIncomingFrames(nextIncomingFrames);
                }
            }
            incomingFrames = extensions[0];

            for (size_t i = len - 1; i >= 0; i--) {
                size_t next = i - 1;
                if (next > 0) {
                    extensions[i].setNextOutgoingFrames(extensions[next]);
                } else {
                    extensions[i].setNextOutgoingFrames(nextOutgoingFrames);
                }
            }
            outgoingFrames = extensions[len - 1];
            return extensions;
        } else {
            incomingFrames = nextIncomingFrames;
            outgoingFrames = nextOutgoingFrames;
            return [];
        }
    }

    protected Extension[] _parse(MetaData metaData) {

        InputRange!string fieldValues = metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString());
        Array!(ExtensionConfig) configList = ExtensionConfig.parseEnum(fieldValues);
        auto r = configList[].filter!(c => factory.isAvailable(c.getName()))
            .map!(delegate Extension (ExtensionConfig c) {
                Extension e = factory.newInstance(c);
                AbstractExtension abstractExtension = cast(AbstractExtension) e;
                if (abstractExtension !is null) 
                    abstractExtension.setConfig(c);
                return e;
            });

        return r.array;
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
