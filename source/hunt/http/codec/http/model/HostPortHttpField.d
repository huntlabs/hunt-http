module hunt.http.codec.http.model.HostPortHttpField;

import hunt.http.codec.http.model.BadMessageException;
import hunt.http.codec.http.model.HostPort;
import hunt.http.HttpField;
import hunt.http.HttpHeader;
import hunt.http.HttpStatus;

import hunt.logging;

class HostPortHttpField : HttpField {
	HostPort _hostPort;

	this(string authority) {
		this(HttpHeader.HOST, HttpHeader.HOST.asString(), authority);
	}

	this(HttpHeader header, string name, string authority) {
		version(HUNT_HTTP_DEBUG)
		tracef("name=%s, authority=%s", name, authority);
		super(header, name, authority);
		try {
			_hostPort = new HostPort(authority);
		} catch (Exception e) {
			throw new BadMessageException(HttpStatus.BAD_REQUEST_400, "Bad HostPort", e);
		}
	}

	/**
	 * Get the host.
	 * 
	 * @return the host
	 */
	string getHost() {
		return _hostPort.getHost();
	}

	/**
	 * Get the port.
	 * 
	 * @return the port
	 */
	int getPort() {
		return _hostPort.getPort();
	}

	/**
	 * Get the port.
	 * 
	 * @param defaultPort
	 *            The default port to return if no port set
	 * @return the port
	 */
	int getPort(int defaultPort) {
		return _hostPort.getPort(defaultPort);
	}
}
