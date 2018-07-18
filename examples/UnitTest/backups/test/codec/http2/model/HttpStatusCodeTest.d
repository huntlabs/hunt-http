module test.codec.http2.model;

import hunt.util.Assert.assertEquals;
import hunt.util.Assert.assertNull;

import hunt.util.Test;

import hunt.http.codec.http.model.HttpMethod;
import hunt.http.codec.http.model.HttpStatus;

public class HttpStatusCodeTest {
	
	public void testInvalidGetCode() {
		assertNull("Invalid code: 800", HttpStatus.getCode(800));
		assertNull("Invalid code: 190", HttpStatus.getCode(190));
	}

	
	public void testHttpMethod() {
		assertEquals("GET", HttpMethod.GET.toString());
	}
}
