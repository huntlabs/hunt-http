module hunt.http.server.http.ServerSessionListener;

import hunt.http.codec.http.stream.Session;

interface ServerSessionListener : Session.Listener {
	/**
	 * <p>
	 * Callback method invoked when a connection has been accepted by the
	 * server.
	 * </p>
	 * 
	 * @param session
	 *            the session
	 */
	void onAccept(Session session);

	/**
	 * <p>
	 * Empty implementation of {@link ServerSessionListener}
	 * </p>
	 */
	static class Adapter : Session.Listener.Adapter , ServerSessionListener {
		override
		void onAccept(Session session) {
		}
	}
}
