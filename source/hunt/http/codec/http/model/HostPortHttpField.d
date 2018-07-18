module hunt.http.codec.http.model.HostPortHttpField;

import hunt.http.codec.http.model.BadMessageException;
import hunt.http.codec.http.model.HostPort;
import hunt.http.codec.http.model.HttpField;
import hunt.http.codec.http.model.HttpHeader;
import hunt.http.codec.http.model.HttpStatus;

class HostPortHttpField :HttpField {
	HostPort _hostPort;

	this(string authority) {
		this(HttpHeader.HOST, HttpHeader.HOST.asString(), authority);
	}

	this(HttpHeader header, string name, string authority) {
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
