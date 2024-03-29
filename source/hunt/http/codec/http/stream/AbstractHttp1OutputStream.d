module hunt.http.codec.http.stream.AbstractHttp1OutputStream;

import hunt.http.HttpOutputStream;
import hunt.http.codec.http.encode.HttpGenerator;

import hunt.http.HttpBody;
import hunt.http.HttpMetaData;
import hunt.http.HttpRequest;
import hunt.http.HttpResponse;

import hunt.io.ByteBuffer;
import hunt.io.BufferUtils;
import hunt.net.Connection;
import hunt.Exceptions;
import hunt.logging;

import std.format;


/**
*/
abstract class AbstractHttp1OutputStream : HttpOutputStream {

    this(HttpMetaData metaData, bool clientMode) {
        super(metaData, clientMode);
    }

    override void commit() {
        commit(cast(ByteBuffer)null);
    }

    protected void commit(ByteBuffer data) {
        if (committed || closed) {
            debug warning("connection closed already, or data committed already.");
            return;
        }

        Connection tcpSession = getSession();
        if(!tcpSession.isConnected()) {
            closed = true;
            string msg = format("connection [id=%d] closed.", tcpSession.getId());
            debug warningf(msg);
            return;
        }
        
        version(HUNT_HTTP_DEBUG) {
            infof("committing data: %s", data.toString());
        }

        HttpGenerator generator = getHttpGenerator();
        HttpGenerator.Result generatorResult;
        ByteBuffer header = getHeaderByteBuffer();

        generatorResult = generate(metaData, header, null, data, false);
        if (generatorResult == HttpGenerator.Result.FLUSH && 
            generator.getState() == HttpGenerator.State.COMMITTED) {
            if (data !is null) {
                // ByteBuffer[] headerAndData = [header, data];
                // tcpSession.encode(headerAndData);
                tcpSession.encode(header);
                tcpSession.encode(data);
            } else {
                tcpSession.encode(header);
            }
            committed = true;
        } else {
            generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                HttpGenerator.Result.FLUSH, HttpGenerator.State.COMMITTED);
        }
    }

    override void write(ByteBuffer data){
        if (closed) {
            warningf("connection closed!");
            return;
        }

        if (!data.hasRemaining())
            return;

        // The browser may close the connection forcely before receiving all data of favicon.ico.
        Connection tcpSession = getSession();
        if(!tcpSession.isConnected()) {
            closed = true;
            string msg = format("connection [id=%d] closed.", tcpSession.getId());
            debug warningf(msg);
            return;
        }            

        HttpGenerator generator = getHttpGenerator();
        HttpGenerator.Result generatorResult;

        if (!committed) {
            commit(data);
        } else {
            if (generator.isChunking()) {
                ByteBuffer chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);

                generatorResult = generate(null, null, chunk, data, false);
                if (generatorResult == HttpGenerator.Result.FLUSH && 
                    generator.getState() == HttpGenerator.State.COMMITTED) {
                    // ByteBuffer[] chunkAndData = [chunk, data];
                    // tcpSession.encode(chunkAndData);
                    tcpSession.encode(chunk);
                    tcpSession.encode(data);
                } else {
                    generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                        HttpGenerator.Result.FLUSH, HttpGenerator.State.COMMITTED);
                }
            } else {
                generatorResult = generate(null, null, null, data, false);
                if (generatorResult == HttpGenerator.Result.FLUSH && 
                    generator.getState() == HttpGenerator.State.COMMITTED) {
                    tcpSession.encode(data);
                } else {
                    generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                        HttpGenerator.Result.FLUSH, HttpGenerator.State.COMMITTED);
                }
            }
        }
    }

    override void close() {
        if (closed) {
            version(HUNT_HTTP_DEBUG) warning("The outstream has been closed.");
            return;
        }

        try {
            version(HUNT_HTTP_DEBUG) trace("The output stream for http1 is closing...");

            if(metaData.haveBody()) {
                version(HUNT_HTTP_DEBUG) tracef("writting body...");
                HttpBody httpBody = metaData.getBody();
                httpBody.writeTo(this);
            }

            HttpGenerator generator = getHttpGenerator();
            Connection tcpSession = getSession();
            HttpGenerator.Result generatorResult;

            if (!committed) {
                ByteBuffer header = getHeaderByteBuffer();
                generatorResult = generate(metaData, header, null, null, true);
                if (generatorResult == HttpGenerator.Result.FLUSH && 
                    generator.getState() == HttpGenerator.State.COMPLETING) {
                    tcpSession.encode(header);
                    generateLastData(generator);
                } else {
                    generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                        HttpGenerator.Result.FLUSH, HttpGenerator.State.COMPLETING);
                }
                committed = true;
            } else {
                if (generator.isChunking()) {
                    version (HUNT_HTTP_DEBUG) tracef("http1 output stream is generating chunk");
                    generatorResult = generate(null, null, null, null, true);
                    if (generatorResult == HttpGenerator.Result.CONTINUE && 
                        generator.getState() == HttpGenerator.State.COMPLETING) {
                        generatorResult = generate(null, null, null, null, true);
                        if (generatorResult == HttpGenerator.Result.NEED_CHUNK && 
                            generator.getState() == HttpGenerator.State.COMPLETING) {
                            generateLastChunk(generator, tcpSession);
                        } else if (generatorResult == HttpGenerator.Result.NEED_CHUNK_TRAILER && 
                            generator.getState() == HttpGenerator.State.COMPLETING) {
                            generateTrailer(generator, tcpSession);
                        }
                    } else {
                        generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                            HttpGenerator.Result.CONTINUE, HttpGenerator.State.COMPLETING);
                    }
                } else {
                    generatorResult = generate(null, null, null, null, true);
                    if (generatorResult == HttpGenerator.Result.CONTINUE && 
                        generator.getState() == HttpGenerator.State.COMPLETING) {
                        generateLastData(generator);
                    } else {
                        generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                            HttpGenerator.Result.CONTINUE, HttpGenerator.State.COMPLETING);
                    }
                }
            }
        } finally {
            closed = true;
            version(HUNT_HTTP_DEBUG) infof("http1 output stream closed");
        }
    }

    private void generateLastChunk(HttpGenerator generator, Connection tcpSession) {
        ByteBuffer chunk = BufferUtils.allocate(HttpGenerator.CHUNK_SIZE);
        HttpGenerator.Result generatorResult = generate(null, null, chunk, null, true);
        if (generatorResult == HttpGenerator.Result.FLUSH && 
            generator.getState() == HttpGenerator.State.COMPLETING) {
            tcpSession.encode(chunk);
            generateLastData(generator);
        } else {
            generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                HttpGenerator.Result.FLUSH, HttpGenerator.State.COMPLETING);
        }
    }

    private void generateTrailer(HttpGenerator generator, Connection tcpSession) {
        ByteBuffer trailer = getTrailerByteBuffer();
        HttpGenerator.Result generatorResult = generate(null, null, trailer, null, true);
        if (generatorResult == HttpGenerator.Result.FLUSH && 
            generator.getState() == HttpGenerator.State.COMPLETING) {
            tcpSession.encode(trailer);
            generateLastData(generator);
        } else {
            generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                HttpGenerator.Result.FLUSH, HttpGenerator.State.COMPLETING);
        }
    }

    private void generateLastData(HttpGenerator generator) {
        HttpGenerator.Result generatorResult = generate(null, null, null, null, true);
        if (generator.getState() == HttpGenerator.State.END) {
            if (generatorResult == HttpGenerator.Result.DONE) {
                generateHttpMessageSuccessfully();
            } else if (generatorResult == HttpGenerator.Result.SHUTDOWN_OUT) {
                getSession().close();
            } else {
                generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                    HttpGenerator.Result.DONE, HttpGenerator.State.END);
            }
        } else {
            generateHttpMessageExceptionally(generatorResult, generator.getState(), 
                HttpGenerator.Result.DONE, HttpGenerator.State.END);
        }
    }

    protected HttpGenerator.Result generate(HttpMetaData metaData, 
        ByteBuffer header, ByteBuffer chunk, ByteBuffer content, bool last) {
        HttpGenerator generator = getHttpGenerator();
        if (clientMode) {
            return generator.generateRequest(cast(HttpRequest) metaData, header, chunk, content, last);
        } else {
            return generator.generateResponse(cast(HttpResponse) metaData, false, header, chunk, content, last);
        }
    }

    abstract protected ByteBuffer getHeaderByteBuffer();

    abstract protected ByteBuffer getTrailerByteBuffer();

    abstract protected Connection getSession();

    abstract protected HttpGenerator getHttpGenerator();

    abstract protected void generateHttpMessageSuccessfully();

    abstract protected void generateHttpMessageExceptionally(HttpGenerator.Result actualResult,
                                                             HttpGenerator.State actualState,
                                                             HttpGenerator.Result expectedResult,
                                                             HttpGenerator.State expectedState);

}
