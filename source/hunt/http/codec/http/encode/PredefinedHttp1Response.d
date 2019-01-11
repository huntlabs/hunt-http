module hunt.http.codec.http.encode.PredefinedHttp1Response;

import hunt.http.codec.http.model;
import hunt.http.codec.http.encode.HttpGenerator;

import hunt.collection.BufferUtils;
import hunt.collection.ByteBuffer;
import hunt.Exceptions;
import hunt.logging;

/**
 * 
 */
abstract class PredefinedHttp1Response {
    __gshared byte[] H2C_BYTES;
    __gshared byte[] CONTINUE_100_BYTES;

    shared static this() {
        HttpResponse H2C_RESPONSE = new HttpResponse(HttpVersion.HTTP_1_1, 101, new HttpFields());
        H2C_RESPONSE.getFields().put(HttpHeader.CONNECTION, HttpHeaderValue.UPGRADE);
        H2C_RESPONSE.getFields().put(HttpHeader.UPGRADE, "h2c");

        try {
            ByteBuffer header = BufferUtils.allocate(128);
            HttpGenerator gen = new HttpGenerator(true, true);
            HttpGenerator.Result result = gen.generateResponse(H2C_RESPONSE, false, header, null, null, true);
            assert(result == HttpGenerator.Result.FLUSH && 
                    gen.getState() == HttpGenerator.State.COMPLETING,
                    "generate h2c bytes error");
            H2C_BYTES = BufferUtils.toArray(header);

            header = BufferUtils.allocate(128);
            gen = new HttpGenerator(true, true);
            result = gen.generateResponse(HttpGenerator.CONTINUE_100_INFO, false, header, null, null, false);
            assert(result == HttpGenerator.Result.FLUSH && 
                    gen.getState() == HttpGenerator.State.COMPLETING_1XX,
                    "generate continue 100 error");
            CONTINUE_100_BYTES = BufferUtils.toArray(header);
        } catch (IOException e) {
            errorf("generate h2c response exception", e);
            throw new CommonRuntimeException(cast(string)e.message);
        }
    }
}
