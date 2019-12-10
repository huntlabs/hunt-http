module hunt.http.routing.handler.ResourceHandler;

import hunt.http.routing.RoutingContext;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.HttpServerRequest;

import hunt.http.Version;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;
import hunt.http.Util;

import hunt.logging.ConsoleLogger;
import hunt.Exceptions;
import hunt.util.DateTime : TimeUnit;
import hunt.util.AcceptMimeType;
import hunt.util.MimeTypeUtils;
import hunt.util.MimeType;

import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.file;
import std.path;
import std.format;
import std.stdio;
import std.string;

/**
 * 
 */
abstract class AbstractResourceHandler : RouteHandler {

    /**
     * If directory listing is enabled.
     */
    private bool _directoryListingEnabled = false; 
    private string _basePath;
    private string _requestFile;
    private size_t _bufferSize = 1024;
    private bool _cachable = true;
    private Duration _cacheTime = -1.seconds;
    
    this(string path) {
		string rootPath = dirName(thisExePath);
        _basePath = buildNormalizedPath(rootPath, path);
    }

    protected string basePath() {
        return _basePath;
    }

    protected string requestFile() {
        return _requestFile;
    }

    bool isBasePath() {
        return _basePath == _requestFile;
    }

    size_t bufferSize() {
        return _bufferSize;
    }

    AbstractResourceHandler bufferSize(size_t size) {
        _bufferSize = size;
        return this;
    }

    bool cachable() {
        return _cachable;
    }

    AbstractResourceHandler cachable(bool flag) {
        _cachable = flag;
        return this;
    }

    Duration cacheTime() {
        return _cacheTime;
    }

    AbstractResourceHandler cacheTime(Duration t) {
        _cacheTime = t;
        return this;
    }

    bool directoryListingEnabled() {
        return _directoryListingEnabled;
    }

    AbstractResourceHandler directoryListingEnabled(bool flag) {
        this._directoryListingEnabled = flag;
        return this;
    }    

    void handle(RoutingContext context) {
        string requestPath = context.getURI().getPath();
        version(HUNT_HTTP_DEBUG) infof("requestPath: %s", requestPath);

        if(requestPath.length <= 1) {
            _requestFile = _basePath;
        } else {
            string p = requestPath[1..$];
            ptrdiff_t index = indexOf(p, "/");
            if(index > 0) {
                p = p[index+1 .. $];
                _requestFile = buildNormalizedPath(_basePath, p);
            } else {
                _requestFile = _basePath;
            }
            
        }

        version(HUNT_HTTP_DEBUG) tracef("requesting %s, base: %s", _requestFile, _basePath);
        if(!_requestFile.startsWith(_basePath)) {
            render(context, HttpStatus.NOT_FOUND_404, null);
            context.succeed(true);
            return;
        }
        
        if(!_requestFile.exists()) {
            version(HUNT_DEBUG) {
                warningf("Failed to get resource %s from base %s, as the path did not exist",
                    _requestFile, _basePath);
            }
            render(context, HttpStatus.NOT_FOUND_404, null);
            context.succeed(true);
            return;
        }

        try {
            render(context, HttpStatus.OK_200, null);
            context.succeed(true);
        } catch(Exception ex) {
            version(HUNT_DEBUG) errorf("http handler exception", ex.msg);
            if (!context.isCommitted()) {
                render(context, HttpStatus.INTERNAL_SERVER_ERROR_500, ex);
                context.fail(ex);
            }            
        }
    }

    abstract void render(RoutingContext context, int status, Exception ex);
}



/**
 * 
 */
class DefaultResourceHandler : AbstractResourceHandler {
    private MimeTypeUtils _mimetypes;

    this(string path) {
        super(path);
        _mimetypes = new MimeTypeUtils();
    }

    override void render(RoutingContext context, int status, Exception t) {
        context.setStatus(status);

        HttpStatusCode code = HttpStatus.getCode(status); 
        if(code == HttpStatusCode.Null)
            code = HttpStatusCode.INTERNAL_SERVER_ERROR;
        
        string requestPath = context.getURI().getPath();

        // string title = status.to!string() ~ " " ~ code.getMessage();
        string title = format("Directory Listing - %s", requestPath);
        string content;
        if(status == HttpStatus.NOT_FOUND_404) {
            content = "The resource " ~ requestPath ~ " is not found";
        } else if(status == HttpStatus.INTERNAL_SERVER_ERROR_500) {
            content = "The server internal error. <br/>" ~ (t !is null ? t.msg : "");
        } else if(requestFile.isDir()) {
            if(directoryListingEnabled()) {
                content = generateContent(context, title);
            } else {
                content = format(`Index of %s`, requestPath);
            }

        } else {
            handleFile(context);
            return;
        }

        respond(context, title, content);
    }

    private void respond(RoutingContext context, string title, string content) {

        context.responseHeader(HttpHeader.CONTENT_TYPE, "text/html");

        context.write("<!DOCTYPE html>\n")
            .write("<html>\n")
            .write("<head>\n")
            .write("<title>")
            .write(title)
            .write("</title>\n")
            .write("</head>\n")
            .write("<body>\n")
            .write("<p>" ~ content ~ "</p>\n")
            .write("<hr/>\n")
            .write("</body>\n")
            .end("</html>\n");
    }

    private void handleFile(RoutingContext context) {

        if(cachable() && cacheTime() > Duration.zero()) {
            context.responseHeader(HttpHeader.CACHE_CONTROL, 
                "public, max-age=" ~ cacheTime().total!(TimeUnit.Second).to!string());
            
            auto expireTime = Clock.currTime(UTC()) + cacheTime();
            context.responseHeader(HttpHeader.EXPIRES, CommonUtil.toRFC822DateTimeString(expireTime));
        }

        // 
        string mime = _mimetypes.getMimeByExtension(requestFile);
        version(HUNT_HTTP_DEBUG) infof("MIME type: %s for %s", mime, requestFile);
        if(!mime.empty()) {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, mime ~ ";charset=utf-8");

            if(mime == "application/json") {
                renderFileContent(context);
            } else {
                AcceptMimeType[] acceptMimes = MimeTypeUtils.parseAcceptMIMETypes(mime);
                if(acceptMimes.length > 0 && acceptMimes[0].getParentType() == "text") {
                    // show the content of file
                    renderFileContent(context);
                } else {
                    downloadFile(context);
                    context.end();
                    context.succeed(true);
                }
            }
            
        } else {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.APPLICATION_OCTET_STREAM_VALUE);
            downloadFile(context);
            context.end();
            context.succeed(true);
        }
    }

    private void downloadFile(RoutingContext context) {
        HttpServerRequest request = context.getRequest();
        HttpServerResponse response = context.getResponse();
        DirEntry fileInfo = DirEntry(requestFile());
        response.setHeader(HttpHeader.ACCEPT_RANGES, "bytes");

        size_t rangeStart = 0;
        size_t rangeEnd = 0;

        size_t fileSize = fileInfo.size();

        if (request.headerExists(HttpHeader.RANGE))
        {
            // https://tools.ietf.org/html/rfc7233
            // Range can be in form "-\d", "\d-" or "\d-\d"
            auto range = request.header(HttpHeader.RANGE.asString()).chompPrefix("bytes=");
            if (range.canFind(','))
            {
                response.setStatus(HttpStatus.NOT_IMPLEMENTED_501);
                return;
            }
            auto s = range.split("-");

            if (s.length != 2) {
                response.setStatus(HttpStatus.BAD_REQUEST_400);
                return;
            }

            try {
                if (s[0].length) {
                    rangeStart = s[0].to!ulong;
                    rangeEnd = s[1].length ? s[1].to!ulong : fileSize;
                } else if (s[1].length) {
                    rangeEnd = fileSize;
                    auto len = s[1].to!ulong;

                    if (len >= rangeEnd)
                        rangeStart = 0;
                    else
                        rangeStart = rangeEnd - len;
                } else {
                    response.setStatus(HttpStatus.BAD_REQUEST_400);
                    return;
                }
            } catch (ConvException e) {
                warning(e.msg);
                version(HUNT_DEBUG) warning(e);
                response.setStatus(HttpStatus.BAD_REQUEST_400);
            }

            if (rangeEnd > fileSize)
                rangeEnd = fileSize;

            if (rangeStart > rangeEnd)
                rangeStart = rangeEnd;

            if (rangeEnd)
                rangeEnd--; // End is inclusive, so one less than length
            // potential integer overflow with rangeEnd - rangeStart == size_t.max is intended. This only happens with empty files, the + 1 will then put it back to 0

            response.setHeader(HttpHeader.CONTENT_LENGTH, to!string(rangeEnd - rangeStart + 1));
            response.setHeader(HttpHeader.CONTENT_RANGE, "bytes %s-%s/%s".format(rangeStart < rangeEnd ? 
                rangeStart : rangeEnd, rangeEnd, fileSize));
            response.setStatus(HttpStatus.PARTIAL_CONTENT_206);
        }
        else
        {
            rangeEnd = fileSize - 1;
            response.setHeader(HttpHeader.CONTENT_LENGTH, fileSize.to!string);
        }

        // write out the file contents
        auto f = std.stdio.File(requestFile(), "r");
        scope(exit) f.close();

        f.seek(rangeStart);
        int remainingSize = rangeEnd.to!uint - rangeStart.to!uint + 1;
        if(remainingSize <= 0) {
            warningf("actualSize:%d, remainingSize=%d", fileSize, remainingSize);
        } else {
            auto buf = f.rawRead(new ubyte[remainingSize]);
            // response.setContent(buf);
            context.write(cast(byte[])buf);
        }
    }

    private void renderFileContent(RoutingContext context) {

        string title = "Content for: " ~ requestFile();

        ubyte[] buffer;
        File f = File(requestFile(), "r");
        size_t total = f.size();

        scope(exit) f.close();

        size_t remaining = total;
        while(remaining > 0 && !f.eof()) {

            if(remaining > bufferSize()) 
                buffer = new ubyte[bufferSize()];
            else 
                buffer = new ubyte[remaining];
            ubyte[] data = f.rawRead(buffer);
            
            if(data.length > 0) {
                context.write(cast(byte[])data);
                remaining -= data.length;
            }
            version(HUNT_HTTP_DEBUG) {
                tracef("read: %s, remaining: %d, eof: %s", 
                    data.length, remaining, f.eof());
            }
        }
        context.end();
    }

    static string convertFileSize(size_t size) {
        if(size < 1024) {
            return size.to!string();
        } else if(size < 1024*1024) {
            return format!("%d KB")(size/1024);
        } else if(size < 1024*1024*1024) {
            return format!("%d MB")(size/(1024*1024));
        } else if(size < 1024*1024*1024*1024) {
            return format!("%d GB")(size/(1024*1024*1024));
        } else {
            return format!("%d TB")(size/(1024*1024*1024*1024));
        }
    }

    private string generateContent(RoutingContext context, string title) {
        Appender!string sb;
        sb.put("<table id='thetable'>\n");
        sb.put("<thead>\n");
        sb.put(format("<tr><th colspan='3'>%s</th></tr>\n", title));
        sb.put("<tr><th>Name</th><th>Last Modified</th><th>Size</th></tr>\n");
        sb.put("</thead>\n");

        sb.put("<tbody>\n");

        if(!isBasePath()) {
            sb.put("<tr><td><a href='../'>../</a></td><td>&nbsp;</td><td>&nbsp;</td></tr>\n");
        }

        foreach(DirEntry file; dirEntries(requestFile(), SpanMode.shallow)) {
            string fileName = baseName(file.name);
            string fileTime = (cast(DateTime)(file.timeLastModified)).toSimpleString();
            if(file.isDir()) {
                string item = `<tr><td><a href='%1$s/'>%1$s/</a></td><td>%2$s</td><td>--</td></tr>`;
                sb.put(format(item, fileName, fileTime));
                sb.put("\n");
            } else {
                string item = `<tr><td><a href='%1$s'>%1$s</a></td><td>%2$s</td><td>%3$s</td></tr>`;
                sb.put(format(item, fileName, fileTime, convertFileSize(file.size)));
                sb.put("\n");
            }
        }
        sb.put("</tbody>\n");
        sb.put("</table>\n");
        sb.put("<tfoot>\n");
        sb.put("<tr><th class='loc footer' colspan='3'>Powered by Hunt-HTTP</th></tr>\n");
        sb.put("</tfoot>\n");

        return sb.data;
    }
}