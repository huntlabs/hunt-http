module hunt.trace.TracingOptions;

class TracingOptions {
    bool enable = false;
    bool b3Required = true;
    string zipkin = "http://127.0.0.1:9411/api/v2/spans";
}
