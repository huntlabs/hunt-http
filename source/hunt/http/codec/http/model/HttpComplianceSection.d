module hunt.http.codec.http.model.HttpComplianceSection;

import std.algorithm;

struct HttpComplianceSection {
    enum HttpComplianceSection Null = HttpComplianceSection("Null", "", "Null");
    enum HttpComplianceSection CASE_INSENSITIVE_FIELD_VALUE_CACHE = HttpComplianceSection("CASE_INSENSITIVE_FIELD_VALUE_CACHE", "", "Use case insensitive field value cache");
    enum HttpComplianceSection METHOD_CASE_SENSITIVE = HttpComplianceSection("METHOD_CASE_SENSITIVE", "https://tools.ietf.org/html/rfc7230#section-3.1.1", "Method is case-sensitive");
    enum HttpComplianceSection FIELD_COLON = HttpComplianceSection("FIELD_COLON", "https://tools.ietf.org/html/rfc7230#section-3.2", "Fields must have a Colon");
    enum HttpComplianceSection FIELD_NAME_CASE_INSENSITIVE = HttpComplianceSection("FIELD_NAME_CASE_INSENSITIVE", "https://tools.ietf.org/html/rfc7230#section-3.2", "Field name is case-insensitive");
    enum HttpComplianceSection NO_WS_AFTER_FIELD_NAME = HttpComplianceSection("NO_WS_AFTER_FIELD_NAME", "https://tools.ietf.org/html/rfc7230#section-3.2.4", "Whitespace not allowed after field name");
    enum HttpComplianceSection NO_FIELD_FOLDING = HttpComplianceSection("NO_FIELD_FOLDING", "https://tools.ietf.org/html/rfc7230#section-3.2.4", "No line Folding");
    enum HttpComplianceSection NO_HTTP_0_9 = HttpComplianceSection("NO_HTTP_0_9", "https://tools.ietf.org/html/rfc7230#appendix-A.2", "No HTTP/0.9");

    private string _name;
    string url;
    string description;

    this(string name, string url, string description) {
        this._name = name;
        this.url = url;
        this.description = description;
    }

    string name() { return _name; }

    string getURL() {
        return url;
    }

    string getDescription() {
        return description;
    }

    size_t toHash() @trusted nothrow {
        return hashOf(_name);
    }  

    int opCmp(ref HttpComplianceSection b) {
        return std.algorithm.cmp(_name, b._name);
    }

    __gshared HttpComplianceSection[string] values;

    shared static this()
    {
        values[CASE_INSENSITIVE_FIELD_VALUE_CACHE.name] = CASE_INSENSITIVE_FIELD_VALUE_CACHE;
        values[METHOD_CASE_SENSITIVE.name] = METHOD_CASE_SENSITIVE;
        values[FIELD_COLON.name] = FIELD_COLON;
        values[FIELD_NAME_CASE_INSENSITIVE.name] = FIELD_NAME_CASE_INSENSITIVE;
        values[NO_WS_AFTER_FIELD_NAME.name] = NO_WS_AFTER_FIELD_NAME;
        values[NO_FIELD_FOLDING.name] = NO_FIELD_FOLDING;
        values[NO_HTTP_0_9.name] = NO_HTTP_0_9;

    }


    static HttpComplianceSection valueOf(string name)
    {
        return values.get(name, HttpComplianceSection.Null);
    }

}
