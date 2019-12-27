module hunt.trace.B3Propagation;


/**
 * Implements <a href="https://github.com/openzipkin/b3-propagation">B3 Propagation</a>
 */

/**
 * 128 or 64-bit trace ID lower-hex encoded into 32 or 16 characters (required)
 */
enum TRACE_ID_NAME = "X-B3-TraceId";
/**
 * 64-bit span ID lower-hex encoded into 16 characters (required)
 */
enum SPAN_ID_NAME = "X-B3-SpanId";
/**
 * 64-bit parent span ID lower-hex encoded into 16 characters (absent on root span)
 */
enum PARENT_SPAN_ID_NAME = "X-B3-ParentSpanId";
/**
 * "1" means report this span to the tracing system, "0" means do not. (absent means defer the
 * decision to the receiver of this header).
 */
enum SAMPLED_NAME = "X-B3-Sampled";
/**
 * "1" implies sampled and is a request to override collection-tier sampling policy.
 */
enum FLAGS_NAME = "X-B3-Flags";