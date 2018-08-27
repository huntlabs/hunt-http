module hunt.http.client.http.SimpleResponse;

import hunt.http.codec.http.model;
// import hunt.http.codec.http.model.MetaData.Response;

// import hunt.http.utils.json.Json;
// import hunt.http.utils.json.JsonArray;
// import hunt.http.utils.json.JsonObject;
// import hunt.http.utils.lang.GenericTypeReference;
import hunt.logger;


// import java.io.ByteArrayInputStream;
import hunt.util.exception;
import hunt.util.functional;
import hunt.io;
import hunt.util.string;

import hunt.container;
// import java.util.Iterator;
// import java.util.Spliterator;
// import java.util.function.Consumer;
// import hunt.util.functional;
// import java.util.stream.Collectors;
// import java.util.zip.GZIPInputStream;

import std.range;

alias Response = MetaData.Response;

/**
*/
class SimpleResponse {

    Response response;
    List!(ByteBuffer) responseBody; // = new ArrayList!ByteBuffer();
    List!Cookie cookies;
    string stringBody;

    this(Response response) {
        responseBody = new ArrayList!ByteBuffer();
        this.response = response;
    }

    HttpVersion getHttpVersion() {
        return response.getHttpVersion();
    }

    HttpFields getFields() {
        return response.getFields();
    }

    long getContentLength() {
        return response.getContentLength();
    }

    InputRange!HttpField iterator() {
        return response.iterator();
    }

    int getStatus() {
        return response.getStatus();
    }

    string getReason() {
        return response.getReason();
    }

    Supplier!HttpFields getTrailerSupplier() {
        return response.getTrailerSupplier();
    }

    // void forEach(Consumer<? super HttpField> action) {
    //     response.forEach(action);
    // }

    // Spliterator!HttpField spliterator() {
    //     return response.spliterator();
    // }

    Response getResponse() {
        return response;
    }

    List!(ByteBuffer) getResponseBody() {
        return responseBody;
    }

    string getStringBody() {
        return getStringBody("UTF-8");
    }

    string getStringBody(string charset) {
        if (stringBody == null) {
            string contentEncoding = getFields().get(HttpHeader.CONTENT_ENCODING);
            if ("gzip".equalsIgnoreCase(contentEncoding)) {
                byte[] bytes = BufferUtils.toArray(responseBody);
                if (bytes != null) {
                    try  {
                        // GZIPInputStream gzipInputStream = new GZIPInputStream(new ByteArrayInputStream(bytes));
                        // return IO.toString(gzipInputStream, charset);
                        implementationMissing();
                        return "";
                    } catch (IOException e) {
                        errorf("unzip exception", e);
                        return null;
                    }
                } else {
                    return null;
                }
            } else {
                stringBody = BufferUtils.toString(responseBody);
                return stringBody;
            }
        } else {
            return stringBody;
        }
    }

    // T getJsonBody(T)(GenericTypeReference!T typeReference) {
    //     return Json.toObject(getStringBody(), typeReference);
    // }

    // T getJsonBody(T)(Class!T clazz) {
    //     return Json.toObject(getStringBody(), clazz);
    // }

    // JsonObject getJsonObjectBody() {
    //     return Json.toJsonObject(getStringBody());
    // }

    // JsonArray getJsonArrayBody() {
    //     return Json.toJsonArray(getStringBody());
    // }

    List!Cookie getCookies() {
        // if (cookies == null) {
        //     cookies = response.getFields().getValuesList(HttpHeader.SET_COOKIE.asString()).stream()
        //                       .map(CookieParser::parseSetCookie).collect(Collectors.toList());
        //     return cookies;
        // } else {
        //     return cookies;
        // }
        
        implementationMissing();
        return cookies;
    }
}
