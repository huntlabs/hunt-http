module hunt.http.codec.http.frame.Flags;

interface Flags {
	enum NONE = 0x00;
	enum END_STREAM = 0x01;
	enum ACK = 0x01;
	enum END_HEADERS = 0x04;
	enum PADDING = 0x08;
	enum PRIORITY = 0x20;
}
