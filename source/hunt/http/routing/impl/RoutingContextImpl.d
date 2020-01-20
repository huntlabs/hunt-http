module hunt.http.routing.impl.RoutingContextImpl;

import hunt.http.routing.impl.RouterImpl;

import hunt.http.routing.handler;
import hunt.http.routing.Router;
import hunt.http.routing.RouterManager;
import hunt.http.routing.RoutingContext;

import hunt.http.HttpMetaData;
import hunt.http.HttpOutputStream;

import hunt.http.server.HttpServerContext;
import hunt.http.server.HttpServerRequest;
import hunt.http.server.HttpServerResponse;
import hunt.http.server.HttpSession;

import hunt.collection;
import hunt.concurrency.Promise;
import hunt.Exceptions;
import hunt.Functions;
import hunt.io.Common;
import hunt.logging.ConsoleLogger;
import hunt.util.Common;

import std.container;
import std.variant;

/**
 * 
 */
class RoutingContextImpl : RoutingContext {
    private HttpServerRequest request;
    private NavigableSet!(RouterMatchResult) routers;
    private RouterMatchResult current;
    private HttpSessionHandler httpSessionHandler;
    private Variant[string] _attributes;
    // private TemplateHandlerSPI templateHandlerSPI = TemplateHandlerSPILoader.getInstance().getTemplateHandlerSPI();
    private bool asynchronousRead = false;
    // private  ConcurrentLinkedDeque<Promise<?>> handlerPromiseQueue;
    private HttpServerContext _context;
    private string _groupName = "default";

    this(HttpServerContext context, NavigableSet!(RouterMatchResult) routers) {
        _context = context;
        request = _context.httpRequest();
        this.routers = routers;
    }

    override Variant getAttribute(string key) {
        return _attributes.get(key, Variant());
    }

    override void setAttribute(string key, Variant value) {
        _attributes[key] = value;
    }

    override Variant removeAttribute(string key) {
        Variant v = _attributes[key];
        _attributes.remove(key);
        return v;
    }

    override Variant[string] getAttributes() {
        return _attributes;
    }

    override HttpServerRequest getRequest() {
        return request;
    }

    override HttpServerResponse getResponse() {
        return _context.httpResponse();
    }

    override void response(HttpServerResponse response) {
        _context.httpResponse = response;
    }

    // override
    // HttpResponse getAsyncResponse() {
    //     return request.getAsyncResponse();
    // }

    override OutputStream outputStream() {
        return _context.outputStream();
    }

    override string getRouterParameter(string name) {
        return current.getParameters().get(name);
    }

    // override
    // RoutingContext onContent(Action1!ByteBuffer handler) {
    //     getRequest().onContent(handler);
    //     asynchronousRead = true;
    //     return this;
    // }

    // override
    // RoutingContext onContentComplete(Action1!HttpRequest handler) {
    //     getRequest().onContentComplete(handler);
    //     asynchronousRead = true;
    //     return this;
    // }

    // override
    // RoutingContext onMessageComplete(Action1!HttpRequest handler) {
    //     getRequest().onMessageComplete(handler);
    //     asynchronousRead = true;
    //     return this;
    // }

    override bool isAsynchronousRead() {
        return asynchronousRead;
    }

    override void enableAsynchronousRead() {
        asynchronousRead = true;
    }

    override void next() {
        current = routers.pollFirst();
        if (current is null)
            return;

        Router r = current.getRouter();
        version (HUNT_HTTP_DEBUG)
            infof("current router: %d", r.getId());
        r.handle(this);
        return;
    }

    override bool hasNext() {
        return !routers.isEmpty();
    }

    // override
    // <T> RoutingContext complete(Promise<T> promise) {
    //     ConcurrentLinkedDeque<Promise<T>> queue = createHandlerPromiseQueueIfAbsent();
    //     queue.push(promise);
    //     return this;
    // }

    // override
    // <T> bool next(Promise<T> promise) {
    //     return complete(promise).next();
    // }

    // override
    // <T> void succeed(T t) {
    //     Optional.ofNullable(handlerPromiseQueue)
    //             .map(ConcurrentLinkedDeque::pop)
    //             .map(p -> (Promise<T>) p)
    //             .ifPresent(p -> p.succeeded(t));
    // }

    // override
    // void fail(Throwable x) {
    //     Optional.ofNullable(handlerPromiseQueue)
    //             .map(ConcurrentLinkedDeque::pop)
    //             .ifPresent(p -> p.failed(x));
    // }

    // private <T> ConcurrentLinkedDeque<Promise<T>> createHandlerPromiseQueueIfAbsent() {
    //     if (handlerPromiseQueue == null) {
    //         handlerPromiseQueue = new ConcurrentLinkedDeque<>();
    //     }
    //     return (ConcurrentLinkedDeque) handlerPromiseQueue;
    // }

    override int getConnectionId() {
        return _context.getConnectionId();
    }

    void close() {
        _context.end();
    }

    override string getParameter(string name) {
        // if(httpRequestBody is null) {
        //     return null;
        // } else {
        //     return httpRequestBody.getParameter(name);
        // }
        return getRequest().getParameter(name);
    }

    override List!string getParameterValues(string name) {
        // if(httpRequestBody is null)
        //     return new EmptyList!string();
        // else
        //     return httpRequestBody.getParameterValues(name);
        return getRequest().getParameterValues(name);
    }

    override Map!(string, List!string) getParameterMap() {
        // if(httpRequestBody is null)
        //     return null;
        // else
        //     return httpRequestBody.getParameterMap();

        return getRequest().getParameterMap();
    }

    // override
    // Collection!Part getParts() {
    //     // return Optional.ofNullable(httpRequestBody)
    //     //                .map(HttpServerRequest::getParts)
    //     //                .orElse(Collections.emptyList());
    //     if(httpRequestBody is null)
    //         return null;
    //     else
    //         return httpRequestBody.getParts();
    // }

    // override
    // Part getPart(string name) {
    //     // return Optional.ofNullable(httpRequestBody)
    //     //                .map(s -> s.getPart(name))
    //     //                .orElse(null);
    //     if(httpRequestBody is null)
    //         return null;
    //     else
    //         return httpRequestBody.getPart(name);
    // }

    // override
    // InputStream getInputStream() {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(HttpServerRequest::getInputStream)
    //                    .orElse(null);
    // }

    // override
    // BufferedReader getBufferedReader() {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(HttpServerRequest::getBufferedReader)
    //                    .orElse(null);
    // }

    override string getStringBody(string charset) {
        // if(httpRequestBody is null)
        //     return request.getStringBody(charset);
        // else
        //     return httpRequestBody.getStringBody(charset);

        return getRequest().getStringBody(charset);
    }

    override string getStringBody() {
        // if(httpRequestBody is null)
        //     return request.getStringBody();
        // else
        //     return httpRequestBody.getStringBody();
        return getRequest().getStringBody();
    }

    // override
    // <T> T getJsonBody(Class<T> clazz) {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(s -> s.getJsonBody(clazz))
    //                    .orElseGet(() -> request.getJsonBody(clazz));
    // }

    // override
    // <T> T getJsonBody(GenericTypeReference<T> typeReference) {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(s -> s.getJsonBody(typeReference))
    //                    .orElseGet(() -> request.getJsonBody(typeReference));

    // }

    // override
    // JsonObject getJsonObjectBody() {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(HttpServerRequest::getJsonObjectBody)
    //                    .orElseGet(request::getJsonObjectBody);
    // }

    // override
    // JsonArray getJsonArrayBody() {
    //     return Optional.ofNullable(httpRequestBody)
    //                    .map(HttpServerRequest::getJsonArrayBody)
    //                    .orElseGet(request::getJsonArrayBody);
    // }

    // override void setHttpBody(HttpServerRequest requestBody) {
    //     this.httpRequestBody = requestBody;
    // }

    override HttpSession getSessionById(string id) {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getSessionById(id);
        }
    }

    override HttpSession getSession() {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getSession();
        }
    }

    override HttpSession getSession(bool create) {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getSession(create);
        }
    }

    override HttpSession getAndCreateSession(int maxAge) {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getAndCreateSession(maxAge);
        }
    }

    override int getSessionSize() {
        if (httpSessionHandler is null) {
            return 0;
        } else {
            return httpSessionHandler.getSessionSize();
        }
    }

    override bool removeSessionById(string id) {
        if (httpSessionHandler is null) {
            return false;
        } else {
            return httpSessionHandler.removeSessionById(id);
        }
    }

    override bool removeSession() {
        if (httpSessionHandler is null) {
            return false;
        } else {
            return httpSessionHandler.removeSession;
        }
    }

    override bool updateSession(HttpSession httpSession) {
        if (httpSessionHandler is null) {
            return false;
        } else {
            return httpSessionHandler.updateSession(httpSession);
        }
    }

    override bool isRequestedSessionIdFromURL() {
        if (httpSessionHandler is null) {
            return false;
        } else {
            return httpSessionHandler.isRequestedSessionIdFromURL();
        }
    }

    override bool isRequestedSessionIdFromCookie() {
        if (httpSessionHandler is null) {
            return false;
        } else {
            return httpSessionHandler.isRequestedSessionIdFromCookie();
        }
    }

    override string getRequestedSessionId() {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getRequestedSessionId();
        }
    }

    override string getSessionIdParameterName() {
        if (httpSessionHandler is null) {
            return null;
        } else {
            return httpSessionHandler.getSessionIdParameterName();
        }
    }

    void setHttpSessionHandler(HttpSessionHandler httpSessionHandler) {
        this.httpSessionHandler = httpSessionHandler;
    }

    // override
    // void renderTemplate(string resourceName, Object scope) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scope);
    // }

    // override
    // void renderTemplate(string resourceName, Object[] scopes) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scopes);
    // }

    // override
    // void renderTemplate(string resourceName, List<Object> scopes) {
    //     templateHandlerSPI.renderTemplate(this, resourceName, scopes);
    // }

    override RoutingContext write(string value) {
        _context.write(value);
        return this;
    }

    override RoutingContext write(byte[] b, int off, int len) {
        _context.write(b, off, len);
        return this;
    }

    override RoutingContext end() {
        _context.end();
        return this;
    }

    override void flush() {
        _context.flush();
    }

    override bool isCommitted() {
        return _context.isCommitted();
    }

    override string groupName() {
        return _groupName;
    }
    
    override void groupName(string name) {
        _groupName = name;
    }
}
