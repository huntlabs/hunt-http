module HttpBenchmark;

import hunt.http.codec.http.decode.HttpParser;
import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.HttpComplianceSection;

import hunt.lang.exception;
import hunt.lang.Charset;

import hunt.container.BufferUtils;
import hunt.container.ByteBuffer;
import hunt.container.ArrayList;
import hunt.container.List;

import hunt.logging;

import std.conv;
import std.range;
import std.stdio;

alias State = HttpParser.State;


class HttpBenchmark {

    private string _host;
    private int _port;
    private string _bad;
    private string _content;
    private string _methodOrVersion;
    private string _uriOrStatus;
    private string _versionOrReason;
    private List!HttpField _fields;
    private List!HttpField _trailers;
    private string[] _hdr;
    private string[] _val;
    private int _headers;
    private bool _early;
    private bool _headerCompleted;
    private bool _messageCompleted;
    private List!HttpComplianceSection _complianceViolation;

    this() {
        _fields = new ArrayList!HttpField();
        _trailers = new ArrayList!HttpField();
        _complianceViolation = new ArrayList!HttpComplianceSection();
        HttpParser.RequestHandler handler = new Handler();
        parser = new HttpParser(handler);
    }
    private HttpParser parser;

    void benchmark(int number = 10) {
        import core.time;
        import std.datetime;
        import hunt.datetime;
        MonoTime startTime = MonoTime.currTime;
        foreach(j ; 0..number) {
            testParseRequest();
        }
        Duration timeElapsed = MonoTime.currTime - startTime;
        size_t t = timeElapsed.total!(TimeUnit.Microsecond)();
        tracef("time consuming (%d), total: %d microseconds, avg: %d microseconds", number, t, t/number);
    }

    void initialize() {
        _bad = null;
        _host = null;
        _content = null;
        _methodOrVersion = null;
        _uriOrStatus = null;
        _versionOrReason = null;
        _hdr = null;
        _val = null;
        _headers = 0;
        _headerCompleted = false;
        _messageCompleted = false;
        _complianceViolation.clear();
    }

    void testParseRequest() {
        initialize();
        string str = `GET /plaintext HTTP/1.1
cache-control: no-cache
Postman-Token: f290cab4-ac2b-46c7-9db8-ca07f5758989
User-Agent: PostmanRuntime/7.4.0
Accept: */*
Host: 127.0.0.1:8080
accept-encoding: gzip, deflate
Connection: keep-alive

`;
        ByteBuffer buffer = BufferUtils.toBuffer(str);
        // HttpParser.RequestHandler handler = new Handler();
        // parser = new HttpParser(handler);        
        parser.parseNext(buffer);
        parser.reset();
    }


    private class Handler : HttpParser.RequestHandler, HttpParser.ResponseHandler, HttpParser.ComplianceHandler {
        
        bool content(ByteBuffer buffer) {
            if (_content == null)
                _content = "";
            string c = BufferUtils.toString(buffer);
            _content = _content ~ c;
            buffer.position(buffer.limit());
            return false;
        }

        
        bool startRequest(string method, string uri, HttpVersion ver) {
            version (HUNT_DEBUG) {
                tracef("server received the request line, %s, %s, %s", method, uri, ver);
            }
            _fields.clear();
            _trailers.clear();
            _headers = -1;
            _hdr = new string[10];
            _val = new string[10];
            _methodOrVersion = method;
            _uriOrStatus = uri;
            _versionOrReason = ver == HttpVersion.Null ? null : ver.asString();
            _messageCompleted = false;
            _headerCompleted = false;
            _early = false;
            return false;
        }

        
        void parsedHeader(HttpField field) {
            _fields.add(field);
            _hdr[++_headers] = field.getName();
            _val[_headers] = field.getValue();

            if (typeid(field) == typeid(HostPortHttpField)) {
                HostPortHttpField hpfield = cast(HostPortHttpField) field;
                _host = hpfield.getHost();
                _port = hpfield.getPort();
            }
        }

        
        bool headerComplete() {
            _content = null;
            _headerCompleted = true;
            return false;
        }

        
        void parsedTrailer(HttpField field) {
            _trailers.add(field);
        }

        
        bool contentComplete() {
            return false;
        }

        
        bool messageComplete() {
            _messageCompleted = true;
            return true;
        }

        
        void badMessage(BadMessageException failure) {
            string reason = failure.getReason();
            _bad = reason.empty ? failure.getCode().to!string : reason;
        }

        void badMessage(int status, string reason) {
            
        }

        
        bool startResponse(HttpVersion ver, int status, string reason) {
            _fields.clear();
            _trailers.clear();
            _methodOrVersion = ver.asString();
            _uriOrStatus = status.to!string;
            _versionOrReason = reason;
            _headers = -1;
            _hdr = new string[10];
            _val = new string[10];
            _messageCompleted = false;
            _headerCompleted = false;
            return false;
        }

        
        void earlyEOF() {
            _early = true;
        }

        
        int getHeaderCacheSize() {
            return 512;
        }

        
        void onComplianceViolation(HttpCompliance compliance, HttpComplianceSection violation, string reason) {
            _complianceViolation.add(violation);
        }
    }
}