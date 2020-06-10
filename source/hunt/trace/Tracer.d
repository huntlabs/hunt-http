module hunt.trace.Tracer;

import hunt.trace.Constrants;
import hunt.trace.Endpoint;
import hunt.trace.Helpers;
import hunt.trace.Span;

import std.string;

// private static Tracer g_tracer;

// Tracer getTracer() {
//     return g_tracer;
// }

// void setTracer(Tracer tracer) {
//     g_tracer = tracer;
// }

__gshared isTraceEnabled = true;


// https://github.com/openzipkin/b3-propagation

class Tracer {
    __gshared EndPoint localEndpoint;
    __gshared bool upload;
    Span root;
    Span[] children;

    this(string spanName, string spanKind = KindOfClient, string b3Header = null) {
        root = new Span();
        root.id = ID;

        if (!b3Header.empty()) {
            // b3={TraceId}-{SpanId}-{SamplingState}-{ParentSpanId}
            string[] args = b3Header.split("-");
            if (args.length >= 3) {
                root.traceId = args[0];
                root.parentId = args[1];
                root.samplingState = args[2];
            }
        } else {
            root.traceId = LID;
        }

        root.name = spanName;
        root.kind = spanKind;
        root.localEndpoint = localEndpoint;
    }

    Span addSpan(string spanName) {
        auto span = new Span();
        span.traceId = root.traceId;
        span.name = spanName;
        span.id = ID;
        span.parentId = root.id;
        span.kind = KindOfClient;
        span.localEndpoint = localEndpoint;
        children ~= span;
        return span;
    }
}
