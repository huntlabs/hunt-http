module hunt.http.codec.http.model.MultiPartOutputStream;

// import java.io.FilterOutputStream;
// import hunt.lang.exception;
// import java.io.OutputStream;
// import java.nio.charset.StandardCharsets;

// class MultiPartOutputStream :FilterOutputStream {

// 	private static byte[] __CRLF = { '\r', '\n' };
// 	private static byte[] __DASHDASH = { '-', '-' };

// 	static string MULTIPART_MIXED = "multipart/mixed";
// 	static string MULTIPART_X_MIXED_REPLACE = "multipart/x-mixed-replace";

// 	private string boundary;
// 	private byte[] boundaryBytes;

// 	private bool inPart = false;

// 	MultiPartOutputStream(OutputStream out) throws IOException {
// 		super(out);

// 		boundary = "hunt" + System.identityHashCode(this) + to!long(System.currentTimeMillis(), 36);
// 		boundaryBytes = boundary.getBytes(StandardCharsets.ISO_8859_1);
// 	}

// 	MultiPartOutputStream(OutputStream out, string boundary) throws IOException {
// 		super(out);

// 		this.boundary = boundary;
// 		boundaryBytes = boundary.getBytes(StandardCharsets.ISO_8859_1);
// 	}

// 	/**
// 	 * End the current part.
// 	 * 
// 	 * @exception IOException
// 	 *                IOException
// 	 */
// 	override
// 	void close() throws IOException {
// 		try {
// 			if (inPart)
// 				out.write(__CRLF);
// 			out.write(__DASHDASH);
// 			out.write(boundaryBytes);
// 			out.write(__DASHDASH);
// 			out.write(__CRLF);
// 			inPart = false;
// 		} finally {
// 			super.close();
// 		}
// 	}

// 	string getBoundary() {
// 		return boundary;
// 	}

// 	OutputStream getOut() {
// 		return out;
// 	}

// 	/**
// 	 * Start creation of the next Content.
// 	 * 
// 	 * @param contentType
// 	 *            the content type of the part
// 	 * @throws IOException
// 	 *             if unable to write the part
// 	 */
// 	void startPart(string contentType) throws IOException {
// 		if (inPart)
// 			out.write(__CRLF);
// 		inPart = true;
// 		out.write(__DASHDASH);
// 		out.write(boundaryBytes);
// 		out.write(__CRLF);
// 		if (contentType != null)
// 			out.write(("Content-Type: " + contentType).getBytes(StandardCharsets.ISO_8859_1));
// 		out.write(__CRLF);
// 		out.write(__CRLF);
// 	}

// 	/**
// 	 * Start creation of the next Content.
// 	 * 
// 	 * @param contentType
// 	 *            the content type of the part
// 	 * @param headers
// 	 *            the part headers
// 	 * @throws IOException
// 	 *             if unable to write the part
// 	 */
// 	void startPart(string contentType, string[] headers) throws IOException {
// 		if (inPart)
// 			out.write(__CRLF);
// 		inPart = true;
// 		out.write(__DASHDASH);
// 		out.write(boundaryBytes);
// 		out.write(__CRLF);
// 		if (contentType != null)
// 			out.write(("Content-Type: " + contentType).getBytes(StandardCharsets.ISO_8859_1));
// 		out.write(__CRLF);
// 		for (int i = 0; headers != null && i < headers.length; i++) {
// 			out.write(headers[i].getBytes(StandardCharsets.ISO_8859_1));
// 			out.write(__CRLF);
// 		}
// 		out.write(__CRLF);
// 	}

// 	override
// 	void write(byte[] b, int off, int len) throws IOException {
// 		out.write(b, off, len);
// 	}
// }
