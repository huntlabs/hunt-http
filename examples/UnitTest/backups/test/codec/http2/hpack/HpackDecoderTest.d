module test.codec.http2.hpack;

import hunt.http.codec.http.hpack.HpackDecoder;
import hunt.http.codec.http.model;
import hunt.util.TypeUtils;

import hunt.Assert;
import hunt.util.Test;

import hunt.io.ByteBuffer;
import java.util.Iterator;



import hunt.Assert;

public class HpackDecoderTest {

    
    public void testDecodeD_3() {
        HpackDecoder decoder = new HpackDecoder(4096, 8192);

        // First request
        string encoded = "828684410f7777772e6578616d706c652e636f6d";
        ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        HttpRequest request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        assertFalse(request.iterator().hasNext());

        // Second request
        encoded = "828684be58086e6f2d6361636865";
        buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        Iterator<HttpField> iterator = request.iterator();
        assertTrue(iterator.hasNext());
        assertEquals(new HttpField("cache-control", "no-cache"), iterator.next());
        assertFalse(iterator.hasNext());

        // Third request
        encoded = "828785bf400a637573746f6d2d6b65790c637573746f6d2d76616c7565";
        buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTPS.asString(), request.getURI().getScheme());
        assertEquals("/index.html", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        iterator = request.iterator();
        assertTrue(iterator.hasNext());
        assertEquals(new HttpField("custom-key", "custom-value"), iterator.next());
        assertFalse(iterator.hasNext());
    }

    
    public void testDecodeD_4() {
        HpackDecoder decoder = new HpackDecoder(4096, 8192);

        // First request
        string encoded = "828684418cf1e3c2e5f23a6ba0ab90f4ff";
        ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        HttpRequest request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        assertFalse(request.iterator().hasNext());

        // Second request
        encoded = "828684be5886a8eb10649cbf";
        buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        Iterator<HttpField> iterator = request.iterator();
        assertTrue(iterator.hasNext());
        assertEquals(new HttpField("cache-control", "no-cache"), iterator.next());
        assertFalse(iterator.hasNext());
    }

    
    public void testDecodeWithArrayOffset() {
        string value = "Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==";

        HpackDecoder decoder = new HpackDecoder(4096, 8192);
        string encoded = "8682418cF1E3C2E5F23a6bA0Ab90F4Ff841f0822426173696320515778685a475270626a70766347567549484e6c633246745a513d3d";
        byte[] bytes = ConverterUtils.fromHexString(encoded);
        byte[] array = new byte[bytes.length + 1];
        System.arraycopy(bytes, 0, array, 1, bytes.length);
        ByteBuffer buffer = BufferUtils.toBuffer(array, 1, bytes.length).slice();

        HttpRequest request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        assertEquals(1, request.getFields().size());
        HttpField field = request.iterator().next();
        assertEquals(HttpHeader.AUTHORIZATION, field.getHeader());
        assertEquals(value, field.getValue());
    }

    
    public void testDecodeHuffmanWithArrayOffset() {
        HpackDecoder decoder = new HpackDecoder(4096, 8192);

        string encoded = "8286418cf1e3c2e5f23a6ba0ab90f4ff84";
        byte[] bytes = ConverterUtils.fromHexString(encoded);
        byte[] array = new byte[bytes.length + 1];
        System.arraycopy(bytes, 0, array, 1, bytes.length);
        ByteBuffer buffer = BufferUtils.toBuffer(array, 1, bytes.length).slice();

        HttpRequest request = (HttpRequest) decoder.decode(buffer);

        assertEquals("GET", request.getMethod());
        assertEquals(HttpScheme.HTTP.asString(), request.getURI().getScheme());
        assertEquals("/", request.getURI().getPath());
        assertEquals("www.example.com", request.getURI().getHost());
        assertFalse(request.iterator().hasNext());
    }

    
    public void testNghttpx() {
        // Response encoded by nghttpx
        string encoded = "886196C361Be940b6a65B6850400B8A00571972e080a62D1Bf5f87497cA589D34d1f9a0f0d0234327690Aa69D29aFcA954D3A5358980Ae112e0f7c880aE152A9A74a6bF3";
        ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        HpackDecoder decoder = new HpackDecoder(4096, 8192);
        HttpResponse response = (HttpResponse) decoder.decode(buffer);

        assertThat(response.getStatus(), is(200));
        assertThat(response.getFields().size(), is(6));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.DATE, "Fri, 15 Jul 2016 02:36:20 GMT")));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.CONTENT_TYPE, "text/html")));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.CONTENT_ENCODING, "")));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.CONTENT_LENGTH, "42")));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.SERVER, "nghttpx nghttp2/1.12.0")));
        assertTrue(response.getFields().contains(new HttpField(HttpHeader.VIA, "1.1 nghttpx")));
    }

    
    public void testTooBigToIndex() {
        string encoded = "44FfEc02Df3990A190A0D4Ee5b3d2940Ec98Aa4a62D127D29e273a0aA20dEcAa190a503b262d8a2671D4A2672a927aA874988a2471D05510750c951139EdA2452a3a548cAa1aA90bE4B228342864A9E0D450A5474a92992a1aA513395448E3A0Aa17B96cFe3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f3f14E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F3E7Cf9f3e7cF9F353F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F7F54f";
        ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        HpackDecoder decoder = new HpackDecoder(128, 8192);
        try {
            decoder.decode(buffer);
            Assert.fail();
        } catch (BadMessageException e) {
            assertThat(e.getCode(), equalTo(HttpStatus.REQUEST_HEADER_FIELDS_TOO_LARGE_431));
            assertThat(e.getReason(), Matchers.startsWith("Indexed field value too large"));
        }
    }

    
    public void testUnknownIndex() {
        string encoded = "BE";
        ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

        HpackDecoder decoder = new HpackDecoder(128, 8192);
        try {
            decoder.decode(buffer);
            Assert.fail();
        } catch (BadMessageException e) {
            assertThat(e.getCode(), equalTo(HttpStatus.BAD_REQUEST_400));
            assertThat(e.getReason(), Matchers.startsWith("Unknown index"));
        }

    }

}
