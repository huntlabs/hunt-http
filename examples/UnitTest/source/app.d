import std.stdio;

import hunt.util.UnitTest;

import test.codec.http2.model.HttpFieldsTest;
import test.codec.http2.model.MultipartFormInputStreamTest;
import test.codec.http2.model.MultipartParserTest;
import test.codec.http2.model.QuotedCSVTest;
import test.codec.http2.model.TestHttpField;
import test.codec.http2.model.CookieTest;

import test.codec.http2.hpack.HpackContextTest;
import test.codec.http2.hpack.HpackDecoderTest;
import test.codec.http2.hpack.HpackEncoderTest;
import test.codec.http2.hpack.HpackTest;
import test.codec.http2.hpack.TestHuffman;

import test.codec.http2.frame.SettingsGenerateParseTest;

import test.codec.http2.decode.HttpParserTest;
import test.codec.http2.decode.Http2DecoderTest;

import test.codec.http2.encode.TestPredefinedHttp1Response;
import test.codec.http2.encode.URLEncodedTest;

import test.codec.websocket.decode.ParserTest;
import test.codec.websocket.decode.RFC6455ExamplesParserTest;
import test.codec.websocket.encode.GeneratorTest;
import test.codec.websocket.frame.WebSocketFrameTest;
import test.codec.websocket.utils.QuoteUtilTest;

import hunt.collection.BufferUtils;
import hunt.Exceptions;
import hunt.logging;
import hunt.http.codec.http.model.HttpHeader;

import HttpBenchmark;

void main() {

	// HttpBenchmark hb = new HttpBenchmark();
	// hb.benchmark(1000);

	// testHpackDecoder();

	// **********************
	// bug
	// **********************

	// **********************
	// test.codec.http2.model
	// **********************

	testUnits!CookieTest(); 
	testUnits!HttpFieldsTest();
	testUnits!MultipartFormInputStreamTest(); 
	testUnits!MultipartParserTest(); 
	testUnits!QuotedCSVTest();
	testUnits!TestHttpField();

	// **********************
	// test.codec.http2.hpack
	// **********************

	testUnits!HpackContextTest(); 
	testUnits!HpackEncoderTest(); 
	testUnits!HpackDecoderTest(); 
	testUnits!TestHuffman(); 
	testUnits!HpackTest(); 

	// **********************
	// test.codec.http2.decode.*
	// **********************

	testUnits!HttpParserTest(); 
	testUnits!Http2DecoderTest();

	// **********************
	// test.codec.http2.encode.*
	// **********************

	testUnits!TestPredefinedHttp1Response();

	// **********************
	// test.codec.http2.frame.*
	// **********************
	testUnits!SettingsGenerateParseTest();
	testUnits!URLEncodedTest();

	// **********************
	// test.codec.websocket.*
	// **********************
	testUnits!GeneratorTest(); 
	testUnits!ParserTest(); 
	testUnits!RFC6455ExamplesParserTest(); 
	testUnits!QuoteUtilTest(); 
	testUnits!WebSocketFrameTest(); 
}

void testHpackDecoder() {
	import hunt.http.codec.http.hpack.HpackDecoder;
	import hunt.http.codec.http.model;
	import hunt.util.TypeUtils;
	import hunt.util.ConverterUtils;

	import hunt.Assert;
	import hunt.util.UnitTest;

	import hunt.collection.ByteBuffer;
	import hunt.collection.Iterator;
	import hunt.http.codec.http.model.DateGenerator;
	import std.datetime;

	// Response encoded by nghttpx
	string encoded = "886196C361Be940b6a65B6850400B8A00571972e080a62D1Bf5f87497cA589D34d1f9a0f0d0234327690Aa69D29aFcA954D3A5358980Ae112e0f7c880aE152A9A74a6bF3";
	encoded = "885f87497cA589D34d1f"; // ok 
	ByteBuffer buffer = BufferUtils.toBuffer(ConverterUtils.fromHexString(encoded));

	tracef("%(%02X %)", buffer.array());

	HpackDecoder decoder = new HpackDecoder(4096, 8192);
	HttpResponse response = cast(HttpResponse) decoder.decode(buffer);
	tracef("status: %d", response.getStatus());
	foreach (HttpField h; response) {
		tracef("%s", h.toString());
	}

	tracef(DateGenerator.formatDate(Clock.currTime));

	trace(Clock.currTime.toSimpleString());
}
