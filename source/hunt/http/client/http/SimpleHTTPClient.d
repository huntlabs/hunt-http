module hunt.http.client.http.SimpleHTTPClient;

import hunt.http.client.http.ClientHTTPHandler;
import hunt.http.client.http.HTTP2Client;
import hunt.http.client.http.HTTP2ClientConnection;
import hunt.http.client.http.HTTPClientConnection;
import hunt.http.client.http.SimpleHTTPClientConfiguration;
import hunt.http.client.http.SimpleResponse;

import hunt.http.util.UrlEncoded;
import hunt.http.codec.http.frame.SettingsFrame;
import hunt.http.codec.http.model;
import hunt.http.codec.http.stream.HTTPOutputStream;

import hunt.container.ArrayList;
import hunt.container.BufferUtils;
import hunt.container.HashMap;

import hunt.util.exception;
import hunt.util.Charset;
import hunt.util.concurrent.CompletableFuture;
import hunt.util.concurrent.Promise;
import hunt.util.functional;
import hunt.util.LifeCycle;
import hunt.util.string;
import hunt.io;
import hunt.logging;

import hunt.container.ByteBuffer;
import hunt.container.List;

import std.string;

alias Response = MetaData.Response;

class SimpleHTTPClient  : AbstractLifeCycle { 

    private HTTP2Client http2Client;
    // private HashMap!(RequestBuilder, AsynchronousPool!(HTTPClientConnection)) poolMap; // = new ConcurrentHashMap!()();
    private SimpleHTTPClientConfiguration config;
    // private Timer responseTimer;
    // private Meter errorMeter;
    // private Counter leakedConnectionCounter;

    this() {
        // poolMap = new HashMap!(RequestBuilder, AsynchronousPool!(HTTPClientConnection))();
        this(new SimpleHTTPClientConfiguration());
    }

    this(SimpleHTTPClientConfiguration http2Configuration) {
        this.config = http2Configuration;
        http2Client = new HTTP2Client(http2Configuration);
        // MetricRegistry metrics = http2Configuration.getTcpConfiguration().getMetricReporterFactory().getMetricRegistry();
        // responseTimer = metrics.timer("http2.SimpleHTTPClient.response.time");
        // errorMeter = metrics.meter("http2.SimpleHTTPClient.error.count");
        // leakedConnectionCounter = metrics.counter("http2.SimpleHTTPClient.leak.count");
        // metrics.register("http2.SimpleHTTPClient.error.ratio.1m", new class RatioGauge {
        //     override
        //     protected Ratio getRatio() {
        //         return Ratio.of(errorMeter.getOneMinuteRate(), responseTimer.getOneMinuteRate());
        //     }
        // });
        start();
    }

    /**
     * The HTTP request builder that helps you to create a new HTTP request.
     */
    class RequestBuilder {
        protected string host;
        protected int port;
        protected MetaData.Request request;

        List!(ByteBuffer) requestBody; // = new ArrayList!(ByteBuffer)();

        Func1!(HTTPClientConnection, CompletableFuture!(bool)) connect;
        Action1!(Response) _headerComplete;
        Action1!ByteBuffer _content;
        Action1!(Response) _contentComplete;
        Action1!(Response) _messageComplete;

        Action3!(int, string, Response) _badMessage;
        Action1!(Response) _earlyEof;

        Promise!(HTTPOutputStream) promise;
        Action1!(HTTPOutputStream) _output;
        // MultiPartContentProvider _multiPartProvider;
        UrlEncoded _formUrlEncoded;

        SettingsFrame settingsFrame;

        Completable!(SimpleResponse) future;
        SimpleResponse simpleResponse;

        protected this() {
            init();
        }

        protected this(string host, int port, MetaData.Request request) {
            this.host = host;
            this.port = port;
            this.request = request;
            init();
        }

        private void init()
        {
            requestBody = new ArrayList!(ByteBuffer)();
        }

        /**
         * Set the cookies.
         *
         * @param cookies The cookies.
         * @return RequestBuilder
         */
        RequestBuilder cookies(List!(Cookie) cookies) {
            request.getFields().put(HttpHeader.COOKIE, CookieGenerator.generateCookies(cookies));
            return this;
        }

        /**
         * Put an HTTP field. It will replace existed field.
         *
         * @param name The field name.
         * @param list The field values.
         * @return RequestBuilder
         */
        RequestBuilder put(string name, List!(string) list) {
            request.getFields().put(name, list);
            return this;
        }

        /**
         * Put an HTTP field. It will replace existed field.
         *
         * @param header The field name.
         * @param value  The field value.
         * @return RequestBuilder
         */
        RequestBuilder put(HttpHeader header, string value) {
            request.getFields().put(header, value);
            return this;
        }

        /**
         * Put an HTTP field. It will replace existed field.
         *
         * @param name  The field name.
         * @param value The field value.
         * @return RequestBuilder
         */
        RequestBuilder put(string name, string value) {
            request.getFields().put(name, value);
            return this;
        }

        /**
         * Put an HTTP field. It will replace existed field.
         *
         * @param field The HTTP field.
         * @return RequestBuilder
         */
        RequestBuilder put(HttpField field) {
            request.getFields().put(field);
            return this;
        }

        /**
         * Add some HTTP fields.
         *
         * @param fields The HTTP fields.
         * @return RequestBuilder
         */
        RequestBuilder addAll(HttpFields fields) {
            request.getFields().addAll(fields);
            return this;
        }

        /**
         * Add an HTTP field.
         *
         * @param field The HTTP field.
         * @return RequestBuilder
         */
        RequestBuilder add(HttpField field) {
            request.getFields().add(field);
            return this;
        }

        /**
         * Get the HTTP trailers.
         *
         * @return The HTTP trailers.
         */
        Supplier!HttpFields getTrailerSupplier() {
            return request.getTrailerSupplier();
        }

        /**
         * Set the HTTP trailers.
         *
         * @param trailers The HTTP trailers.
         * @return RequestBuilder
         */
        RequestBuilder setTrailerSupplier(Supplier!HttpFields trailers) {
            request.setTrailerSupplier(trailers);
            return this;
        }

        /**
         * Set the JSON HTTP body data.
         *
         * @param obj The JSON HTTP body data. The HTTP client will serialize the object when the request is submitted.
         * @return RequestBuilder
         */
        // RequestBuilder jsonBody(Object obj) {
        //     return put(HttpHeader.CONTENT_TYPE, MimeTypes.Type.APPLICATION_JSON_UTF_8.asString()).body(Json.toJson(obj));
        // }

        /**
         * Set the text HTTP body data.
         *
         * @param content The text HTTP body data.
         * @return RequestBuilder
         */
        RequestBuilder bodyContent(string c) {
            return bodyContent(c, StandardCharsets.UTF_8);
        }

        /**
         * Set the text HTTP body data.
         *
         * @param content The text HTTP body data.
         * @param charset THe charset of the text.
         * @return RequestBuilder
         */
        RequestBuilder bodyContent(string c, string charset) {
            return write(BufferUtils.toBuffer(c));
        }

        /**
         * Write HTTP body data. When you submit the request, the data will be sent.
         *
         * @param buffer The HTTP body data.
         * @return RequestBuilder
         */
        RequestBuilder write(ByteBuffer buffer) {
            requestBody.add(buffer);
            return this;
        }

        /**
         * Set a output stream callback. When the HTTP client creates the HTTPOutputStream, it will execute this callback.
         *
         * @param output The output stream callback.
         * @return RequestBuilder
         */
        RequestBuilder onOutput(Action1!(HTTPOutputStream) o) {
            this._output = o;
            return this;
        }

        /**
         * Set a output stream callback. When the HTTP client creates the HTTPOutputStream, it will execute this callback.
         *
         * @param promise The output stream callback.
         * @return RequestBuilder
         */
        RequestBuilder onOutput(Promise!(HTTPOutputStream) promise) {
            this.promise = promise;
            return this;
        }

        // MultiPartContentProvider multiPartProvider() {
        //     if (_multiPartProvider is null) {
        //         _multiPartProvider = new MultiPartContentProvider();
        //         put(HttpHeader.CONTENT_TYPE, _multiPartProvider.getContentType());
        //     }
        //     return _multiPartProvider;
        // }

        /**
         * Add a multi-part mime content. Such as a file.
         *
         * @param name    The content name.
         * @param content The ContentProvider that helps you read the content.
         * @param fields  The header fields of the content.
         * @return RequestBuilder
         */
        // RequestBuilder addFieldPart(string name, ContentProvider content, HttpFields fields) {
        //     multiPartProvider().addFieldPart(name, content, fields);
        //     return this;
        // }

        /**
         * Add a multi-part mime content. Such as a file.
         *
         * @param name     The content name.
         * @param fileName The content file name.
         * @param content  The ContentProvider that helps you read the content.
         * @param fields   The header fields of the content.
         * @return RequestBuilder
         */
        // RequestBuilder addFilePart(string name, string fileName, ContentProvider content, HttpFields fields) {
        //     multiPartProvider().addFilePart(name, fileName, content, fields);
        //     return this;
        // }

        UrlEncoded formUrlEncoded() {
            if (_formUrlEncoded is null) {
                _formUrlEncoded = new UrlEncoded();
                put(HttpHeader.CONTENT_TYPE, "application/x-www-form-urlencoded");
            }
            return _formUrlEncoded;
        }

        /**
         * Add a value in an existed form parameter. The form content type is "application/x-www-form-urlencoded".
         *
         * @param name  The parameter name.
         * @param value The parameter value.
         * @return RequestBuilder
         */
        RequestBuilder addFormParam(string name, string value) {
            formUrlEncoded().add(name, value);
            return this;
        }

        /**
         * Add some values in an existed form parameter. The form content type is "application/x-www-form-urlencoded".
         *
         * @param name   The parameter name.
         * @param values The parameter values.
         * @return RequestBuilder
         */
        RequestBuilder addFormParam(string name, List!(string) values) {
            formUrlEncoded().addValues(name, values);
            return this;
        }

        /**
         * Put a parameter in the form content. The form content type is "application/x-www-form-urlencoded".
         *
         * @param name  The parameter name.
         * @param value The parameter value.
         * @return RequestBuilder
         */
        RequestBuilder putFormParam(string name, string value) {
            formUrlEncoded().put(name, value);
            return this;
        }

        /**
         * Put a parameter in the form content. The form content type is "application/x-www-form-urlencoded".
         *
         * @param name   The parameter name.
         * @param values The parameter values.
         * @return RequestBuilder
         */
        RequestBuilder putFormParam(string name, List!(string) values) {
            formUrlEncoded().putValues(name, values);
            return this;
        }

        /**
         * Remove a parameter in the form content. The form content type is "application/x-www-form-urlencoded".
         *
         * @param name The parameter name.
         * @return RequestBuilder
         */
        RequestBuilder removeFormParam(string name) {
            formUrlEncoded().remove(name);
            return this;
        }

        /**
         * Set the connection establishing callback.
         *
         * @param connect the connection establishing callback
         * @return RequestBuilder
         */
        RequestBuilder onConnect(Func1!(HTTPClientConnection, CompletableFuture!(bool)) c) {
            this.connect = c;
            return this;
        }

        //  CompletableFuture!(bool)) connect() { return this.connect; }

        /**
         * Set the HTTP header complete callback.
         *
         * @param headerComplete The HTTP header complete callback. When the HTTP client receives all HTTP headers,
         *                       it will execute this action.
         * @return RequestBuilder
         */
        RequestBuilder headerComplete(Action1!(Response) h) {
            this._headerComplete = h;
            return this;
        }

        Action1!(Response) headerComplete() {
            return this._headerComplete;
        }

        /**
         * Set the HTTP message complete callback.
         *
         * @param messageComplete The HTTP message complete callback. When the HTTP client receives the complete HTTP message
         *                        that contains HTTP headers and body, it will execute this action.
         * @return RequestBuilder
         */
        RequestBuilder messageComplete(Action1!(Response) m) {
            this._messageComplete = m;
            return this;
        }

        /**
         * Set the HTTP content receiving callback.
         *
         * @param content The HTTP content receiving callback. When the HTTP client receives the HTTP body data,
         *                it will execute this action. This action will be executed many times.
         * @return RequestBuilder
         */
        RequestBuilder content(Action1!ByteBuffer c) {
            this._content = c;
            return this;
        }

        /**
         * Set the HTTP content complete callback.
         *
         * @param contentComplete The HTTP content complete callback. When the HTTP client receives the HTTP body finish,
         *                        it will execute this action.
         * @return RequestBuilder
         */
        RequestBuilder contentComplete(Action1!(Response) c) {
            this._contentComplete = c;
            return this;
        }

        /**
         * Set the bad message callback.
         *
         * @param badMessage The bad message callback. When the HTTP client parses an incorrect message format,
         *                   it will execute this action. The callback has three parameters.
         *                   The first parameter is the bad status code.
         *                   The second parameter is the reason.
         *                   The third parameter is HTTP response.
         * @return RequestBuilder
         */
        RequestBuilder badMessage(Action3!(int, string, Response) b) {
            this._badMessage = b;
            return this;
        }

        /**
         * Set the early EOF callback.
         *
         * @param earlyEof The early EOF callback. When the HTTP client encounters an error, it will execute this action.
         * @return RequestBuilder
         */
        RequestBuilder earlyEof(Action1!(Response) e) {
            this._earlyEof = e;
            return this;
        }

        /**
         * send an HTTP2 settings frame
         *
         * @param settingsFrame The HTTP2 settings frame
         * @return RequestBuilder
         */
        RequestBuilder settings(SettingsFrame settingsFrame) {
            this.settingsFrame = settingsFrame;
            return this;
        }

        /**
         * Submit an HTTP request.
         *
         * @return The CompletableFuture of HTTP response.
         */
        Completable!(SimpleResponse) submit() {
            submit(new Completable!(SimpleResponse)());
            return future;
        }

        /**
         * Submit an HTTP request.
         *
         * @return The CompletableFuture of HTTP response.
         */
        CompletableFuture!(SimpleResponse) toFuture() {
            return submit();
        }

        /**
         * Submit an HTTP request.
         *
         * @param future The HTTP response callback.
         */
        void submit(Completable!(SimpleResponse) future) {
            this.future = future;
            send(this);
        }

        /**
         * Submit an HTTP request.
         *
         * @param action The HTTP response callback.
         */
        void submit(Action1!(SimpleResponse) action) {
            Completable!(SimpleResponse) future = new class Completable!(SimpleResponse) {
                override void succeeded(SimpleResponse t) {
                    super.succeeded(t);
                    action(t);
                }

                override void failed(Exception c) {
                    super.failed(c);
                    errorf("http request exception", c);
                }
            };
            submit(future);
        }

        /**
         * Submit an HTTP request.
         */
        void end() {
            send(this);
        }

        override
        bool opEquals(Object o) {
            if (this is o) return true;
            if (o is null || typeid(this) != typeid(o)) return false;
            RequestBuilder that = cast(RequestBuilder) o;
            return port == that.port && host == that.host;
        }

        // override
        // size_t toHash() @trusted nothrow {
        //     return hashOf(host, port);
        // }

    }

    /**
     * Remove the HTTP connection pool.
     *
     * @param url The host URL.
     */
    // void removeConnectionPool(string url) {
    //     try {
    //         removeConnectionPool(new HttpURI(url));
    //     } catch (MalformedURLException e) {
    //         errorf("url exception", e);
    //         throw new IllegalArgumentException(e);
    //     }
    // }

    /**
     * Remove the HTTP connection pool.
     *
     * @param url The host URL.
     */
    // void removeConnectionPool(HttpURI url) {
    //     RequestBuilder req = new RequestBuilder();
    //     req.host = url.getHost();
    //     req.port = url.getPort() < 0 ? url.getDefaultPort() : url.getPort();
    //     removePool(req);
    // }

    /**
     * Remove the HTTP connection pool.
     *
     * @param host The host URL.
     * @param port The target port.
     */
    // void removeConnectionPool(string host, int port) {
    //     RequestBuilder req = new RequestBuilder();
    //     req.host = host;
    //     req.port = port;
    //     removePool(req);
    // }

    // private void removePool(RequestBuilder req) {
    //     AsynchronousPool!(HTTPClientConnection) pool = poolMap.remove(req);
    //     pool.stop();
    // }

    /**
     * Get the HTTP connection pool size.
     *
     * @param host The host name.
     * @param port The target port.
     * @return The HTTP connection pool size.
     */
    // int getConnectionPoolSize(string host, int port) {
    //     RequestBuilder req = new RequestBuilder();
    //     req.host = host;
    //     req.port = port;
    //     return _getPoolSize(req);
    // }

    /**
     * Get the HTTP connection pool size.
     *
     * @param url The host URL.
     * @return The HTTP connection pool size.
     */
    // int getConnectionPoolSize(string url) {
    //     try {
    //         return getConnectionPoolSize(new HttpURI(url));
    //     } catch (MalformedURLException e) {
    //         errorf("url exception", e);
    //         throw new IllegalArgumentException(e);
    //     }
    // }

    /**
     * Get the HTTP connection pool size.
     *
     * @param url The host URL.
     * @return The HTTP connection pool size.
     */
    // int getConnectionPoolSize(HttpURI url) {
    //     RequestBuilder req = new RequestBuilder();
    //     req.host = url.getHost();
    //     req.port = url.getPort() < 0 ? url.getDefaultPort() : url.getPort();
    //     return _getPoolSize(req);
    // }

    // private int _getPoolSize(RequestBuilder req) {
    //     AsynchronousPool!(HTTPClientConnection) pool = poolMap.get(req);
    //     if (pool != null) {
    //         return pool.size();
    //     } else {
    //         return 0;
    //     }
    // }

    /**
     * Create a RequestBuilder with GET method and URL.
     *
     * @param url The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder get(string url) {
        return request(HttpMethod.GET.asString(), url);
    }

    /**
     * Create a RequestBuilder with POST method and URL.
     *
     * @param url The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder post(string url) {
        return request(HttpMethod.POST.asString(), url);
    }

    /**
     * Create a RequestBuilder with HEAD method and URL.
     *
     * @param url The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder head(string url) {
        return request(HttpMethod.HEAD.asString(), url);
    }

    /**
     * Create a RequestBuilder with PUT method and URL.
     *
     * @param url The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder put(string url) {
        return request(HttpMethod.PUT.asString(), url);
    }

    /**
     * Create a RequestBuilder with DELETE method and URL.
     *
     * @param url The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder del(string url) {
        return request(HttpMethod.DELETE.asString(), url);
    }

    /**
     * Create a RequestBuilder with HTTP method and URL.
     *
     * @param method HTTP method.
     * @param url    The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder request(HttpMethod method, string url) {
        return request(method.asString(), url);
    }

    /**
     * Create a RequestBuilder with HTTP method and URL.
     *
     * @param method HTTP method.
     * @param url    The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder request(string method, string url) {
        try {
            return request(method, new HttpURI(url));
        } catch (MalformedURLException e) {
            errorf("url exception", e);
            throw new IllegalArgumentException(e.msg);
        }
    }

    /**
     * Create a RequestBuilder with HTTP method and URL.
     *
     * @param method HTTP method.
     * @param url    The request URL.
     * @return A new RequestBuilder that helps you to build an HTTP request.
     */
    RequestBuilder request(string method, HttpURI url) {
        try {
            RequestBuilder req = new RequestBuilder();
            req.host = url.getHost();
            req.port = url.getPort() < 0 ? 80 : url.getPort();
            HttpURI httpURI = url; // new HttpURI(url.toURI());
            if (!(httpURI.getPath().strip().empty())) {
                httpURI.setPath("/");
            }
            req.request = new MetaData.Request(method, httpURI, HttpVersion.HTTP_1_1, new HttpFields());
            return req;
        } catch (URISyntaxException e) {
            errorf("url exception", e);
            throw new IllegalArgumentException(e.msg);
        }
    }

    /**
     * Register an health check task.
     *
     * @param task The health check task.
     */
    // void registerHealthCheck(Task task) {
    //     auto healthCheck = config.getHealthCheck();
    //     if(healthCheck !is null)
    //         healthCheck.register(task);

    //     // Optional.ofNullable(config.getHealthCheck())
    //     //         .ifPresent(healthCheck -) healthCheck.register(task));
    // }

    /**
     * Clear the health check task.
     *
     * @param name The task name.
     */
    // void clearHealthCheck(string name) {
    //     auto healthCheck = config.getHealthCheck();
    //     if(healthCheck !is null)
    //         healthCheck.clear(name);
    //     // Optional.ofNullable(config.getHealthCheck())
    //     //         .ifPresent(healthCheck -) healthCheck.clear(name));
    // }

    protected void send(RequestBuilder reqBuilder) {

        string host = reqBuilder.host;
        int port = reqBuilder.port;

        tracef("Creating connection: %s:%d", host, port);

        Completable!HTTPClientConnection connFuture = http2Client.connect(host, port);
        connFuture.thenAccept( (HTTPClientConnection connection) {
            infof("Connection created: %s:%d, using %s", host, port, typeid(cast(Object)connection));

            if (connection.getHttpVersion() == HttpVersion.HTTP_2) {
                if (reqBuilder.settingsFrame !is null) {
                    HTTP2ClientConnection http2ClientConnection = cast(HTTP2ClientConnection) connection;
                    http2ClientConnection.getHttp2Session().settings(reqBuilder.settingsFrame, Callback.NOOP);
                }
            }

            if (reqBuilder.connect !is null) {
                CompletableFuture!(bool) r = reqBuilder.connect(connection);

                bool isSendReq = r.get();
                if (isSendReq) {
                    send(reqBuilder, connection, createClientHTTPHandler(reqBuilder, connection));
                } else {
                    IO.close(connection);
                }
                // .exceptionally( (ex) {
                //     IO.close(connection);
                // });
            } else {
                send(reqBuilder, connection, createClientHTTPHandler(reqBuilder, connection));
            }

        });


        // Timer.Context resTimerCtx = responseTimer.time();
        // getPool(reqBuilder).take().thenAccept( (pooledConn) {
        //     HTTPClientConnection connection = pooledConn.getObject();

        //     if (connection.getHttpVersion() == HttpVersion.HTTP_2) {
        //         if (reqBuilder.settingsFrame != null) {
        //             HTTP2ClientConnection http2ClientConnection = cast(HTTP2ClientConnection) connection;
        //             http2ClientConnection.getHttp2Session().settings(reqBuilder.settingsFrame, Callback.NOOP);
        //         }
        //         pooledConn.release();
        //     }
        //     version(HuntDebugMode) {
        //         tracef("take the connection %s from pool, released: %s, %s", connection.getSessionId(), pooledConn.isReleased(), connection.getHttpVersion());
        //     }

        //     if (reqBuilder.connect != null) {
        //         reqBuilder.connect(connection).thenAccept((isSendReq ) {
        //             if (isSendReq) {
        //                 send(reqBuilder, connection, createClientHTTPHandler(reqBuilder, pooledConn));
        //             } else {
        //                 IO.close(connection);
        //             }
        //         }).exceptionally( (ex) {
        //             IO.close(connection);
        //             return null;
        //         });
        //     } else {
        //         send(reqBuilder, connection, createClientHTTPHandler(reqBuilder, pooledConn));
        //     }
        // }).exceptionally( (e) {
        //     errorf("SimpleHTTPClient sends message exception", e);
        //     // resTimerCtx.stop();
        //     // errorMeter.mark();
        //     return null;
        // });
    }

    protected void send(RequestBuilder reqBuilder, HTTPClientConnection connection, ClientHTTPHandler handler) {

        List!(ByteBuffer) requestBody = reqBuilder.requestBody;

        if (requestBody !is null && !requestBody.isEmpty()) {
            connection.send(reqBuilder.request, requestBody.toArray(), handler);
        } else if (reqBuilder.promise !is null) {
            connection.send(reqBuilder.request, reqBuilder.promise, handler);
        } else if (reqBuilder._output !is null) {
            Promise!(HTTPOutputStream) p = new class Promise!(HTTPOutputStream) {
                void succeeded(HTTPOutputStream ot) {
                    reqBuilder._output(ot);
                }

                void failed(Exception x) {
                    implementationMissing(false);
                }

                string id() { return "SimpleHttpClient HTTPOutputStream"; }

            };
            connection.send(reqBuilder.request, p, handler);
        // } else if (reqBuilder.multiPartProvider != null) {
        //     IO.close(reqBuilder.multiPartProvider);
        //     reqBuilder.multiPartProvider.setListener(() => tracef("multi part content listener"));
        //     if (reqBuilder.multiPartProvider.getLength() > 0) {
        //         reqBuilder.put(HttpHeader.CONTENT_LENGTH, string.valueOf(reqBuilder.multiPartProvider.getLength()));
        //     }
        //     Completable!(HTTPOutputStream) p = new Completable!()();
        //     connection.send(reqBuilder.request, p, handler);
        //     p.thenAccept( (output) {
        //         try  {
        //             HTTPOutputStream ot = output;
        //             foreach (ByteBuffer buf ; reqBuilder.multiPartProvider) {
        //                 ot.write(buf);
        //             }
        //         } catch (IOException e) {
        //             errorf("SimpleHTTPClient writes data exception", e);
        //         }
        //     }).exceptionally( (t) {
        //         errorf("SimpleHTTPClient gets output stream exception", t);
        //         // resTimerCtx.stop();
        //         // errorMeter.mark();
        //         return null;
        //     });
        } else if (reqBuilder._formUrlEncoded !is null) {
            string bd = reqBuilder._formUrlEncoded.encode((config.getCharacterEncoding()), true);
            byte[] content = cast(byte[])bd; // StringUtils.getBytes(bd);
            connection.send(reqBuilder.request, ByteBuffer.wrap(content), handler);
        } else {
            connection.send(reqBuilder.request, handler);
        }        

        // if (!CollectionUtils.isEmpty(reqBuilder.requestBody)) {
        //     connection.send(reqBuilder.request, reqBuilder.requestBody.toArray(BufferUtils.EMPTY_BYTE_BUFFER_ARRAY), handler);
        // } else if (reqBuilder.promise !is null) {
        //     connection.send(reqBuilder.request, reqBuilder.promise, handler);
        // } else if (reqBuilder.output !is null) {
        //     Promise!(HTTPOutputStream) p = new class Promise!(HTTPOutputStream) {
        //         void succeeded(HTTPOutputStream ot) {
        //             reqBuilder.output(ot);
        //         }
        //     };
        //     connection.send(reqBuilder.request, p, handler);
        // } else if (reqBuilder.multiPartProvider != null) {
        //     IO.close(reqBuilder.multiPartProvider);
        //     reqBuilder.multiPartProvider.setListener(() => tracef("multi part content listener"));
        //     if (reqBuilder.multiPartProvider.getLength() > 0) {
        //         reqBuilder.put(HttpHeader.CONTENT_LENGTH, string.valueOf(reqBuilder.multiPartProvider.getLength()));
        //     }
        //     Completable!(HTTPOutputStream) p = new Completable!()();
        //     connection.send(reqBuilder.request, p, handler);
        //     p.thenAccept( (output) {
        //         try  {
        //             HTTPOutputStream ot = output;
        //             foreach (ByteBuffer buf ; reqBuilder.multiPartProvider) {
        //                 ot.write(buf);
        //             }
        //         } catch (IOException e) {
        //             errorf("SimpleHTTPClient writes data exception", e);
        //         }
        //     }).exceptionally( (t) {
        //         errorf("SimpleHTTPClient gets output stream exception", t);
        //         // resTimerCtx.stop();
        //         // errorMeter.mark();
        //         return null;
        //     });
        // } else if (reqBuilder.formUrlEncoded != null) {
        //     string body = reqBuilder.formUrlEncoded.encode(Charset.forName(config.getCharacterEncoding()), true);
        //     byte[] content = StringUtils.getBytes(body, config.getCharacterEncoding());
        //     connection.send(reqBuilder.request, ByteBuffer.wrap(content), handler);
        // } else {
        //     connection.send(reqBuilder.request, handler);
        // }
    }

    protected ClientHTTPHandler createClientHTTPHandler(RequestBuilder reqBuilder,
                                                        // Timer.Context resTimerCtx,
                                                        // PooledObject!(HTTPClientConnection) pooledConn) {
                                                        HTTPClientConnection pooledConn) {
        return (new ClientHTTPHandler.Adapter() ).headerComplete((req, resp, outputStream, conn) {

            auto header = reqBuilder.headerComplete;
            if(header !is null)
                header(resp);

            if (reqBuilder.future !is null) {
                if (reqBuilder.simpleResponse is null) {
                    reqBuilder.simpleResponse = new SimpleResponse(resp);
                }
            }
            return HttpMethod.HEAD.asString() == req.getMethod() && messageComplete(reqBuilder, pooledConn, resp);
        }).content((buffer, req, resp, outputStream, conn) {
            auto c = reqBuilder._content;
            if(c !is null)
                c(buffer);
            if (reqBuilder.future !is null) {
                auto r = reqBuilder.simpleResponse;
                auto b = r.responseBody;
                if(b !is null)
                    b.add(buffer); 
                // Optional.ofNullable(reqBuilder.simpleResponse).map(r -> r.responseBody).ifPresent(body -> body.add(buffer));
            }
            return false;
        }).contentComplete((req, resp, outputStream, conn) {
            auto content = reqBuilder._contentComplete;
            if(content !is null)
                content(resp);
            // Optional.ofNullable(reqBuilder.contentComplete).ifPresent(content -) content(resp));
            return false;
        }).badMessage((errCode, reason, req, resp, outputStream, conn) {
            try {
                auto bad = reqBuilder._badMessage;
                if(bad !is null)
                     bad(errCode, reason, resp);
                // Optional.ofNullable(reqBuilder.badMessage).ifPresent(bad -) bad(errCode, reason, resp));
                if (reqBuilder.future !is null) {
                    if (reqBuilder.simpleResponse is null) {
                        reqBuilder.simpleResponse = new SimpleResponse(resp);
                    }
                    reqBuilder.future.failed(new BadMessageException(errCode, reason));
                }
            } finally {
                // errorMeter.mark();
                // resTimerCtx.stop();
                // IO.close(pooledConn.getObject());
                // pooledConn.release();
                version(HuntDebugMode) {
                    tracef("bad message of the connection %s, released: %s", pooledConn.getSessionId(), "pooledConn.isReleased()");
                }
            }
        }).earlyEOF(delegate void (req, resp, outputStream, conn) {
            try {
                auto e = reqBuilder._earlyEof;
                if(e !is null)
                    e(resp);
                // Optional.ofNullable(reqBuilder.earlyEof).ifPresent(e -) e(resp));
                if (reqBuilder.future !is null) {
                    if (reqBuilder.simpleResponse is null) {
                        reqBuilder.simpleResponse = new SimpleResponse(resp);
                    }
                    reqBuilder.future.failed(new EofException("early eof"));
                }
            } finally {
                // errorMeter.mark();
                // resTimerCtx.stop();
                // IO.close(pooledConn.getObject());
                // pooledConn.release();
                version(HuntDebugMode) {
                    // tracef("early EOF of the connection %s, released: %s", pooledConn.getObject().getSessionId(), pooledConn.isReleased());
                }
            }
        }).messageComplete((req, resp, outputStream, conn) => messageComplete(reqBuilder, pooledConn, resp));
    }

    private bool messageComplete(RequestBuilder reqBuilder,
                                    // Timer.Context resTimerCtx,
                                    // PooledObject!(HTTPClientConnection) pooledConn,
                                    HTTPClientConnection pooledConn,
                                    Response resp) {
        try {
            auto msg = reqBuilder._messageComplete;
            if(msg !is null)
                msg(resp);
            auto f = reqBuilder.future;
            if(f !is null)
                f.succeeded(reqBuilder.simpleResponse);
            // Optional.ofNullable(reqBuilder.messageComplete).ifPresent(msg -) msg(resp));
            // Optional.ofNullable(reqBuilder.future).ifPresent(f -) f.succeeded(reqBuilder.simpleResponse));
            return true;
        } finally {
            // resTimerCtx.stop();
            // pooledConn.release();
            version(HuntDebugMode) {
                tracef("complete request of the connection %s , released: %s", pooledConn.getSessionId(), "pooledConn.isReleased()");
            }
        }
    }


    // protected HTTPClientConnection createConnection(RequestBuilder request) {
    //     string host = request.host;
    //     int port = request.port;

    //     tracef("Creating connection: %s:%d", host, port);

    //     Completable!HTTPClientConnection connFuture = http2Client.connect(host, port);

    //     import core.thread;
    //     import std.datetime;
    //     auto r = connFuture.get();
    //     while(r is null)
    //     {
    //         Thread.sleep(dur!("msecs")(15));
    //         trace("waiting ...");
    //         r = connFuture.get();
    //     }

    //     tracef("Connection created: %s:%d", host, port);

    //     return connFuture.get();
    // }

    // protected AsynchronousPool!(HTTPClientConnection) getPool(RequestBuilder request) {
    //     return poolMap.computeIfAbsent(request, &createConnectionPool);
    // }

    // protected AsynchronousPool!(HTTPClientConnection) createConnectionPool(RequestBuilder request) {
    //     string host = request.host;
    //     int port = request.port;
    //     return new class BoundedAsynchronousPool!(HTTPClientConnection) {
    //         this()
    //         {
    //             super(
    //             config.getPoolSize(),
    //             config.getConnectTimeout(),
    //             (pool) { // The pooled object factory
    //                 Completable!(PooledObject!(HTTPClientConnection)) pooledConn = new Completable!()();
    //                 Completable!(HTTPClientConnection) connFuture = http2Client.connect(host, port);
    //                 connFuture.thenAccept( (conn) {
    //                     string leakMessage = StringUtils.replace(
    //                             "The Hunt HTTP client connection leaked. id -> %s, host -> %s:%s",
    //                             conn.getSessionId(), host, port);
    //                     PooledObject!(HTTPClientConnection) pooledObject = new  class PooledObject!(HTTPClientConnection) {
    //                         this()
    //                         {
    //                             super(conn, pool, () { // connection leak callback
    //                                 leakedConnectionCounter.inc();
    //                                 errorf(leakMessage);
    //                             });
    //                         }
    //                     }; 

    //                     conn.onClose(c => pooledObject.release())
    //                         .onException((c, exception) => pooledObject.release());
    //                     pooledConn.succeeded(pooledObject);
    //                 }).exceptionally( (e) {
    //                     pooledConn.failed(e);
    //                     return null;
    //                 });
    //                 return pooledConn;
    //             },
    //             pooledObject => pooledObject.getObject().isOpen(), // The connection validator
    //             (pooledObject) { // Destroyed connection
    //                 try {
    //                     pooledObject.getObject().close();
    //                 } catch (IOException e) {
    //                     warningf("close http connection exception", e);
    //                 }
    //             },
    //             () => info("The Hunt HTTP client has not any connections leaked. host -) %s:%s", host, port)
    //             );
    //         }
    //     };  
    // }

    override
    protected void init() {
        // auto r = config.getHealthCheck();
        // if(r !is null)
        //     r.start();
        // Optional.ofNullable(config.getHealthCheck()).ifPresent(HealthCheck::start);
    }

    override
    protected void destroy() {
        http2Client.stop();
        // poolMap.forEach((k, v) -) v.stop());
        // foreach(k, v; poolMap)
        //     v.stop();
        
        // auto r = config.getHealthCheck();
        // if(r !is null)
        //     r.stop();
        // Optional.ofNullable(config.getHealthCheck()).ifPresent(HealthCheck::stop);
    }
}
