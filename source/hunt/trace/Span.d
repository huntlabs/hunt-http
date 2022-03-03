module hunt.trace.Span;

import hunt.trace.Endpoint;
import hunt.trace.Constrants;
import hunt.trace.Annotation;
import hunt.trace.Helpers;

import hunt.logging;
import hunt.serialization.JsonSerializer;
import hunt.serialization.Common;

import std.json;
import std.range;
import std.socket;
import std.string;

/**
 * 
 */
class Span {

    /// 16bytes
    string traceId;
    string name;
    @Ignore string parentId;
    /// 8bytes
    string id;
    string kind;
    long timestamp;
    long duration;
    @Ignore bool debug_;
    @Ignore bool shared_;

    EndPoint localEndpoint;
    EndPoint remoteEndpoint;
    Annotation[] annotations;
    string[string] tags;

    string samplingState = "1";

    string defaultId() {
        // b3={TraceId}-{SpanId}-{SamplingState}-{ParentSpanId}
        if(parentId.empty) {
            return traceId ~ "-" ~ id ~ "-" ~ samplingState;
        } else {
            return traceId ~ "-" ~ id ~ "-" ~ samplingState ~ "-" ~ parentId;
        }
    }

    void addTag(string key, string value) {
        tags[key] = value;
    }

    void addAnnotation(string value, long timestamp = 0) {
        auto anno = new Annotation();
        anno.value = value;
        if (timestamp == 0)
            timestamp = usecs;
        anno.timestamp = timestamp;
        annotations ~= anno;
    }

    void start(long timestamp = 0) {
        if (timestamp != 0)
            this.timestamp = timestamp;
        else
            this.timestamp = usecs;
    }

    void finish(long timestamp = 0) {
        if (timestamp != 0)
            this.duration = timestamp - this.timestamp;
        else
            this.duration = usecs - this.timestamp;

    }

    static EndPoint buildLocalEndPoint(string name) {
        EndPoint endpoint = new EndPoint();
        endpoint.serviceName = name;

        try {
            auto addresses = getAddress("localhost");
            foreach (address; addresses) {
                // writefln("  IP: %s", address.toAddrString());
                string ip = address.toAddrString();
                if(ip.startsWith("::")) {
                    // localEndpoint.ipv6 = ip; // todo
                } else {
                    endpoint.ipv4 = ip;
                }
            }
        } catch(Exception ex) {
            warning(ex.msg);
        }

        return endpoint;
    }

    override string toString() {
        auto json = toJson(this);
        json["debug"] = (debug_);
        json["shared"] = (shared_);

        // import hunt.logging;
        // warning("parentId: ", parentId);
        // warning("traceId: ", traceId);
        if (parentId.length != 0)
            json["parentId"] = parentId;
        return json.toString;
    }
}



void traceSpanAfter(Span span, string[string] tags, string error = "") {
    assert(span !is null);
    
    foreach (k, v; tags) {
        span.addTag(k, v);
    }

    if (error != "") {
        span.addTag(SPAN_ERROR, error);
    }
    span.finish();

    // warning(span.toString());
}