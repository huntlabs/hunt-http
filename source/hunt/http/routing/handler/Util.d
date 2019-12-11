module hunt.http.routing.handler.Util;

import hunt.http.routing.RoutingContext;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.HttpServerRequest;

import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

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
struct RoutingHandlerUtils {

    static void downloadFile(RoutingContext context, string requestFile) {
        HttpServerRequest request = context.getRequest();
        HttpServerResponse response = context.getResponse();
        DirEntry fileInfo = DirEntry(requestFile);
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
        auto f = std.stdio.File(requestFile, "r");
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

    static void renderFileContent(RoutingContext context, string requestFile, size_t bufferSize = 8*1024) {

        string title = "Content for: " ~ requestFile;

        ubyte[] buffer;
        File f = File(requestFile, "r");
        size_t total = f.size();

        scope(exit) f.close();

        size_t remaining = total;
        while(remaining > 0 && !f.eof()) {

            if(remaining > bufferSize) 
                buffer = new ubyte[bufferSize];
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
    }

}