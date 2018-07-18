module hunt.http.codec.http.stream.FlowControlStrategy;

import hunt.http.codec.http.frame.WindowUpdateFrame;

import hunt.http.codec.http.stream.StreamSPI;
import hunt.http.codec.http.stream.SessionSPI;

interface FlowControlStrategy {
	enum int DEFAULT_WINDOW_SIZE = 65535;

	void onStreamCreated(StreamSPI stream);

	void onStreamDestroyed(StreamSPI stream);

	void updateInitialStreamWindow(SessionSPI session, int initialStreamWindow, bool local);

	void onWindowUpdate(SessionSPI session, StreamSPI stream, WindowUpdateFrame frame);

	void onDataReceived(SessionSPI session, StreamSPI stream, int length);

	void onDataConsumed(SessionSPI session, StreamSPI stream, int length);

	void windowUpdate(SessionSPI session, StreamSPI stream, WindowUpdateFrame frame);

	void onDataSending(StreamSPI stream, int length);

	void onDataSent(StreamSPI stream, int length);
}
