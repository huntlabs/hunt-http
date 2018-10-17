module hunt.http.codec.http.model.HostPort;

import hunt.lang.exception;
import hunt.string;

import std.array;
import std.string;

/**
 * Parse an authority string into Host and Port
 * <p>
 * Parse a string in the form "host:port", handling IPv4 an IPv6 hosts
 * </p>
 *
 */
class HostPort {
	private string _host;
	private int _port;

	this(string authority) {
		if (authority.empty)
			throw new IllegalArgumentException("No Authority");
		try {
			if (authority[0] == '[') {
				// ipv6reference
				int close = cast(int)authority.lastIndexOf(']');
				if (close < 0)
					throw new IllegalArgumentException("Bad IPv6 host");
				_host = authority[0..close + 1];

				if (authority.length > close + 1) {
					if (authority[close + 1] != ':')
						throw new IllegalArgumentException("Bad IPv6 port");
					_port = StringUtils.toInt(authority, close + 2);
				} else
					_port = 0;
			} else {
				// ipv4address or hostname
				int c = cast(int)authority.lastIndexOf(':');
				if (c >= 0) {
					_host = authority[0..c];
					_port = StringUtils.toInt(authority, c + 1);
				} else {
					_host = authority;
					_port = 0;
				}
			}
		} catch (IllegalArgumentException iae) {
			throw iae;
		} catch (Exception ex) {
			throw new IllegalArgumentException("Bad HostPort");
		}
		if (_host.empty())
			throw new IllegalArgumentException("Bad host");
		if (_port < 0)
			throw new IllegalArgumentException("Bad port");
	}

	/**
	 * Get the host.
	 * 
	 * @return the host
	 */
	string getHost() {
		return _host;
	}

	/**
	 * Get the port.
	 * 
	 * @return the port
	 */
	int getPort() {
		return _port;
	}

	/**
	 * Get the port.
	 * 
	 * @param defaultPort,
	 *            the default port to return if a port is not specified
	 * @return the port
	 */
	int getPort(int defaultPort) {
		return _port > 0 ? _port : defaultPort;
	}

	/**
	 * Normalize IPv6 address as per https://www.ietf.org/rfc/rfc2732.txt
	 * 
	 * @param host
	 *            A host name
	 * @return Host name surrounded by '[' and ']' as needed.
	 */
	static string normalizeHost(string host) {
		// if it is normalized IPv6 or could not be IPv6, return
		if (host.empty() || host[0] == '[' || host.indexOf(':') < 0)
			return host;

		// normalize with [ ]
		return "[" ~ host ~ "]";
	}
}
