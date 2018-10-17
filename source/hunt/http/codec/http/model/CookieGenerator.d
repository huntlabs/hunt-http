module hunt.http.codec.http.model.CookieGenerator;

import hunt.http.codec.http.model.Cookie;

import hunt.container.List;

import hunt.lang.exception;
import hunt.string;

import std.array;

// import hunt.http.utils.VerifyUtils;

abstract class CookieGenerator {

	static string generateCookies(List!Cookie cookies) {
		if (cookies is null) {
			throw new IllegalArgumentException("the cookie list is null");
		}

		if (cookies.size() == 1) {
			return generateCookie(cookies.get(0));
		} else if (cookies.size() > 1) {
			StringBuilder sb = new StringBuilder();

			sb.append(generateCookie(cookies.get(0)));
			for (int i = 1; i < cookies.size(); i++) {
				sb.append(';').append(generateCookie(cookies.get(i)));
			}

			return sb.toString();
		} else {
			throw new IllegalArgumentException("the cookie list size is 0");
		}
	}

	static string generateCookie(Cookie cookie) {
		if (cookie is null) {
			throw new IllegalArgumentException("the cookie is null");
		} else {
			return cookie.getName() ~ "=" ~ cookie.getValue();
		}
	}

	static string generateSetCookie(Cookie cookie) {
		if (cookie is null) {
			throw new IllegalArgumentException("the cookie is null");
		} else {
			StringBuilder sb = new StringBuilder();

			sb.append(cookie.getName()).append('=').append(cookie.getValue());

			if (!empty(cookie.getComment())) {
				sb.append(";Comment=").append(cookie.getComment());
			}

			if (!empty(cookie.getDomain())) {
				sb.append(";Domain=").append(cookie.getDomain());
			}
			if (cookie.getMaxAge() >= 0) {
				sb.append(";Max-Age=").append(cookie.getMaxAge());
			}

			string path = empty(cookie.getPath()) ? "/" : cookie.getPath();
			sb.append(";Path=").append(path);

			if (cookie.getSecure()) {
				sb.append(";Secure");
			}

			sb.append(";Version=").append(cookie.getVersion());

			return sb.toString();
		}
	}

	// static string generateServletSetCookie(javax.servlet.http.Cookie cookie) {
	// 	if (cookie == null) {
	// 		throw new IllegalArgumentException("the cookie is null");
	// 	} else {
	// 		StringBuilder sb = new StringBuilder();

	// 		sb.append(cookie.getName()).append('=').append(cookie.getValue());

	// 		if (VerifyUtils.isNotEmpty(cookie.getComment())) {
	// 			sb.append(";Comment=").append(cookie.getComment());
	// 		}

	// 		if (VerifyUtils.isNotEmpty(cookie.getDomain())) {
	// 			sb.append(";Domain=").append(cookie.getDomain());
	// 		}
	// 		if (cookie.getMaxAge() >= 0) {
	// 			sb.append(";Max-Age=").append(cookie.getMaxAge());
	// 		}

	// 		string path = VerifyUtils.isEmpty(cookie.getPath()) ? "/" : cookie.getPath();
	// 		sb.append(";Path=").append(path);

	// 		if (cookie.getSecure()) {
	// 			sb.append(";Secure");
	// 		}

	// 		sb.append(";Version=").append(cookie.getVersion());

	// 		return sb.toString();
	// 	}
	// }
}
