module hunt.http.routing.handler.ResourceHandler;

import hunt.http.routing.handler.Util;

import hunt.http.routing.RoutingContext;

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

    enum string CurrentRequestFile = "CurrentRequestFile";

    /**
     * If directory listing is enabled.
     */
    private bool _isListingEnabled = false; 
    private string _virtualPath;
    private string _basePath;
    // private string requestPath;
    private size_t _bufferSize = 1024;
    private bool _cachable = true;
    private Duration _cacheTime = -1.seconds;
    private int _slashNumberInVirtualPath = 0;
    
    this(string virtualPath, string actualPath) {
        assert(virtualPath[$-1] == '/');
		string rootPath = dirName(thisExePath);
        _basePath = buildNormalizedPath(rootPath, actualPath);
        _virtualPath = virtualPath;
        _slashNumberInVirtualPath = cast(int)count(virtualPath, "/");
    }

    protected string basePath() {
        return _basePath;
    }

    // protected string requestFile() {
    //     return requestPath;
    // }

    // bool isBasePath() {
    //     return _basePath == requestPath;
    // }

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

    bool isListingEnabled() {
        return _isListingEnabled;
    }

    AbstractResourceHandler isListingEnabled(bool flag) {
        _isListingEnabled = flag;
        return this;
    }    

    void handle(RoutingContext context) {
        // string requestPath = context.getURI().getPath();
        string requestPath = context.getRequest().originalPath();
        version(HUNT_HTTP_DEBUG) infof("requestPath: %s, virtualPath: %s", requestPath, _virtualPath);
        bool isDirectory = true;

        if(requestPath.length <= 1) {
            requestPath = _basePath;
        } else {
            // mapping virtual path which contains multiparts like /a/b/c to the actual base
            isDirectory = requestPath[$-1] == '/';

            string[] parts = split(requestPath, "/");
            parts = parts[_slashNumberInVirtualPath .. $];

            string p = buildPath(parts);
            version(HUNT_HTTP_DEBUG) tracef("stripped path: %s", p);
            requestPath = buildNormalizedPath(_basePath, p); // no tailing '/'
            if(isDirectory) requestPath ~= "/";
        }

        version(HUNT_HTTP_DEBUG) tracef("actual path: %s, base: %s", requestPath, _basePath);

        
        if(requestPath.exists()) {

            try {
                context.setAttribute(CurrentRequestFile, requestPath);
                render(context, HttpStatus.OK_200, null);
                context.succeed(true);
            } catch(Exception ex) {
                version(HUNT_DEBUG) errorf("http handler exception", ex.msg);
                if (!context.isCommitted()) {
                    render(context, HttpStatus.INTERNAL_SERVER_ERROR_500, ex);
                    context.fail(ex);
                }            
            }
        } else {
            version(HUNT_DEBUG) {
                warningf("Failed to get resource %s from base %s, as the path did not exist",
                    requestPath, _basePath);
            }
            context.next();
        }
    }

    abstract void render(RoutingContext context, int status, Exception ex);
}



/**
 * 
 */
class DefaultResourceHandler : AbstractResourceHandler {
    private MimeTypeUtils _mimetypes;

    this(string virtualPath, string actualPath) {
        super(virtualPath, actualPath);
        _mimetypes = new MimeTypeUtils();
    }

    override void render(RoutingContext context, int status, Exception t) {
        context.setStatus(status);

        HttpStatusCode code = HttpStatus.getCode(status); 
        if(code == HttpStatusCode.Null)
            code = HttpStatusCode.INTERNAL_SERVER_ERROR;
        
        string requestPath = context.getURI().getPath();

        version(HUNY_HTTP_DEBUG) {
            tracef("path: %s, status: %d", requestPath, status);
        }

        // string title = status.to!string() ~ " " ~ code.getMessage();
        string title = format("Directory Listing - %s", requestPath);
        string content;
        if(status == HttpStatus.NOT_FOUND_404) {
            content = "The resource " ~ requestPath ~ " is not found";
        } else if(status == HttpStatus.INTERNAL_SERVER_ERROR_500) {
            content = "The server internal error. <br/>" ~ (t !is null ? t.msg : "");
        } else {
            string requestFile = context.getAttribute(CurrentRequestFile).get!string();
            if(requestFile.isDir()) {
                version(HUNT_HTTP_DEBUG) {
                    tracef("Try to list a directory: %s", requestFile);
                }
                if(isListingEnabled()) {
                    content = renderFileList(basePath(), requestFile, format(`Index of %s`, requestPath));
                } else {
                    content = format(`Index of %s`, requestPath);
                }

            } else {
                version(HUNT_HTTP_DEBUG) {
                    tracef("Rendering a file: %s", requestFile);
                }
                handleRequestFile(context, requestFile);
                return;
            }
        }

        renderDefaults(context, title, content);
    }

    private void renderDefaults(RoutingContext context, string title, string content) {

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

    private void handleRequestFile(RoutingContext context, string requestFile) {

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
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, mime);

            if(mime == "application/json") {
                RoutingHandlerUtils.renderFileContent(context, requestFile, bufferSize());
            } else {
                AcceptMimeType[] acceptMimes = MimeTypeUtils.parseAcceptMIMETypes(mime);
                if(acceptMimes.length > 0 && acceptMimes[0].getParentType() == "text") {
                    // show the content of file
                    RoutingHandlerUtils.renderFileContent(context, requestFile, bufferSize());
                } else {
                    RoutingHandlerUtils.downloadFile(context, requestFile);
                }
            }
            context.end();
            context.succeed(true);
        } else {
            context.getResponseHeaders().put(HttpHeader.CONTENT_TYPE, MimeType.APPLICATION_OCTET_STREAM_VALUE);
            RoutingHandlerUtils.downloadFile(context, requestFile);
            context.end();
            context.succeed(true);
        }
    }

    static string convertFileSize(ulong size) {
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

    static string renderFileList(string basePath, string requestFile,  string title) {
        Appender!string sb;
        sb.put(format!("<h1>%s</h1><hr>\n")(title));
        sb.put("<table id='thetable' style='width: 800px;border-collapse: collapse;'>\n");
        sb.put("<thead>\n");
        sb.put("<tr><th width='auto'>Name</th><th width='200px'>Last Modified</th><th width='60px'>Size</th></tr>\n");
        sb.put("</thead>\n");

        sb.put("<tbody>\n");

        if(basePath != requestFile) {
            sb.put("<tr><td><a href='../'>../</a></td><td>&nbsp;</td><td>&nbsp;</td></tr>\n");
        }

        foreach(DirEntry file; dirEntries(requestFile, SpanMode.shallow)) {
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
        // sb.put("<tfoot>\n");
        // sb.put("<tr><th class='loc footer' colspan='3'>Powered by Hunt-HTTP</th></tr>\n");
        // sb.put("</tfoot>\n");

        return sb.data;
    }
}