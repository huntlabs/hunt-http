module test.codec.http2.model.CookieTest;

import hunt.collection.ArrayList;
import hunt.collection.List;
import hunt.Assert;

import hunt.http.Cookie;
// import hunt.http.codec.http.model.CookieGenerator;
// import hunt.http.codec.http.model.CookieParser;

import std.conv;

class CookieTest {
	
	void testSetCookie() {
		Cookie cookie = new Cookie("test31", "hello");
		cookie.setDomain("www.huntlabs.net");
		cookie.setPath("/test/hello");
		cookie.setMaxAge(10);
		cookie.setSecure(true);
		cookie.setComment("commenttest");
		cookie.setVersion(20);
		
		string setCookieString = generateSetCookie(cookie);
		
		Cookie setCookie = parseSetCookie(setCookieString);
		Assert.assertThat(setCookie.getName(), ("test31"));
		Assert.assertThat(setCookie.getValue(), ("hello"));
		Assert.assertThat(setCookie.getDomain(), ("www.huntlabs.net"));
		Assert.assertThat(setCookie.getPath(), ("/test/hello"));
		Assert.assertThat(setCookie.getSecure(), (true));
		Assert.assertThat(setCookie.getComment(), ("commenttest"));
		Assert.assertThat(setCookie.getVersion(), (20));
	}

	
	void testCookie() {
		Cookie cookie = new Cookie("test21", "hello");
		string cookieString = generateCookie(cookie);
		
		Cookie[] list = parseCookie(cookieString);
		Assert.assertThat(cast(int)list.length, (1));
		Assert.assertThat(list[0].getName(), ("test21"));
		Assert.assertThat(list[0].getValue(), ("hello"));
	}
	
	
	void testCookieList() {
		List!Cookie list = new ArrayList!Cookie();
		for (int i = 0; i < 10; i++) {
			list.add(new Cookie("test" ~ i.to!string(), "hello" ~ i.to!string()));
		}
		string cookieString = generateCookies(list);
		
		Cookie[] ret = parseCookie(cookieString);
		Assert.assertThat(cast(int)ret.length, (10));
		for (int i = 0; i < 10; i++) {
			Assert.assertThat(ret[i].getName(), ("test" ~ i.to!string()));
			Assert.assertThat(ret[i].getValue(), ("hello" ~ i.to!string()));
		}
	}
}
