module hunt.http.codec.http.model.MultiPartWriter;

// import java.io.FilterWriter;
// import hunt.Exceptions;
// import java.io.Writer;

// class MultiPartWriter :FilterWriter {

// 	private static string __CRLF = "\015\012";
// 	private static string __DASHDASH = "--";

// 	static string MULTIPART_MIXED = MultiPartOutputStream.MULTIPART_MIXED;
// 	static string MULTIPART_X_MIXED_REPLACE = MultiPartOutputStream.MULTIPART_X_MIXED_REPLACE;

// 	private string boundary;

// 	private bool inPart = false;

// 	this(Writer out) throws IOException {
// 		super(out);
// 		boundary = "hunt" + System.identityHashCode(this) + to!long(System.currentTimeMillis(), 36);

// 		inPart = false;
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
// 			out.write(boundary);
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

// 	/**
// 	 * Start creation of the next Content.
// 	 * 
// 	 * @param contentType
// 	 *            the content type
// 	 * @throws IOException
// 	 *             if unable to write the part
// 	 */
// 	void startPart(string contentType) throws IOException {
// 		if (inPart)
// 			out.write(__CRLF);
// 		out.write(__DASHDASH);
// 		out.write(boundary);
// 		out.write(__CRLF);
// 		out.write("Content-Type: ");
// 		out.write(contentType);
// 		out.write(__CRLF);
// 		out.write(__CRLF);
// 		inPart = true;
// 	}

// 	/**
// 	 * end creation of the next Content.
// 	 * 
// 	 * @throws IOException
// 	 *             if unable to write the part
// 	 */
// 	void endPart() throws IOException {
// 		if (inPart)
// 			out.write(__CRLF);
// 		inPart = false;
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
// 		out.write(__DASHDASH);
// 		out.write(boundary);
// 		out.write(__CRLF);
// 		out.write("Content-Type: ");
// 		out.write(contentType);
// 		out.write(__CRLF);
// 		for (int i = 0; headers != null && i < headers.length; i++) {
// 			out.write(headers[i]);
// 			out.write(__CRLF);
// 		}
// 		out.write(__CRLF);
// 		inPart = true;
// 	}

// }
