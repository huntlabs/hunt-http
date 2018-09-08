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

    List!(Extension) parse(MetaData metaData) {
        assert(nextIncomingFrames !is null, "The next incoming frames MUST be not null");
        assert(nextOutgoingFrames !is null, "The next outgoing frames MUST be not null");

        List!(Extension) extensions = _parse(metaData);
        if (extensions !is null && extensions.size() > 0) {
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
            return new EmptyList!Extension();
        }
    }

    protected List!(Extension) _parse(MetaData metaData) {

        implementationMissing(false);
        return null;
        // return parseEnum(metaData.getFields().getValues(HttpHeader.SEC_WEBSOCKET_EXTENSIONS.asString()))
        //         .stream().filter(c -> factory.isAvailable(c.getName()))
        //         .map(c -> {
        //             Extension e = factory.newInstance(c);
        //             if (e instanceof AbstractExtension) {
        //                 AbstractExtension abstractExtension = (AbstractExtension) e;
        //                 abstractExtension.setConfig(c);
        //             }
        //             return e;
        //         })
        //         .collect(Collectors.toList());
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
