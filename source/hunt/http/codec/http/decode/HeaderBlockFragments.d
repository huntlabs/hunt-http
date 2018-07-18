module hunt.http.codec.http.decode.HeaderBlockFragments;

import hunt.container.ByteBuffer;

import hunt.http.codec.http.frame.PriorityFrame;

class HeaderBlockFragments {
	private PriorityFrame priorityFrame;
	private bool endStream;
	private int streamId;
	private ByteBuffer storage;

	void storeFragment(ByteBuffer fragment, int length, bool last) {
		if (storage is null) {
			int space = last ? length : length * 2;
			storage = ByteBuffer.allocate(space);
		}

		// Grow the storage if necessary.
		if (storage.remaining() < length) {
			int space = last ? length : length * 2;
			int capacity = storage.position() + space;
			ByteBuffer newStorage = ByteBuffer.allocate(capacity);
			storage.flip();
			newStorage.put(storage);
			storage = newStorage;
		}

		// Copy the fragment into the storage.
		int limit = fragment.limit();
		fragment.limit(fragment.position() + length);
		storage.put(fragment);
		fragment.limit(limit);
	}

	PriorityFrame getPriorityFrame() {
		return priorityFrame;
	}

	void setPriorityFrame(PriorityFrame priorityFrame) {
		this.priorityFrame = priorityFrame;
	}

	bool isEndStream() {
		return endStream;
	}

	void setEndStream(bool endStream) {
		this.endStream = endStream;
	}

	ByteBuffer complete() {
		ByteBuffer result = storage;
		storage = null;
		result.flip();
		return result;
	}

	int getStreamId() {
		return streamId;
	}

	void setStreamId(int streamId) {
		this.streamId = streamId;
	}
}
