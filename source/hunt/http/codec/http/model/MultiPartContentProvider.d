module hunt.http.codec.http.model.MultiPartContentProvider;

// import hunt.util.functional;
// import hunt.http.utils.exception.CommonRuntimeException;
import hunt.logger;

import hunt.container.ByteBuffer;

// import java.io.ByteArrayOutputStream;
// import java.io.Closeable;
// module hunt.util.exception;
// import java.nio.charset.StandardCharsets;
// import java.util;
// import java.util.concurrent.atomic.AtomicBoolean;

/**
 * 
 */
// class MultiPartContentProvider :AbstractTypedContentProvider : AsyncContentProvider, Closeable {

    
//     private static byte[] COLON_SPACE_BYTES = new byte[]{':', ' '};
//     private static byte[] CR_LF_BYTES = new byte[]{'\r', '\n'};

//     private List<Part> parts = new ArrayList<>();
//     private ByteBuffer firstBoundary;
//     private ByteBuffer middleBoundary;
//     private ByteBuffer onlyBoundary;
//     private ByteBuffer lastBoundary;
//     private AtomicBoolean closed = new AtomicBoolean();
//     private Listener listener;
//     private long length = -1;

//     MultiPartContentProvider() {
//         this(makeBoundary());
//     }

//     MultiPartContentProvider(string boundary) {
//         super("multipart/form-data; boundary=" + boundary);
//         string firstBoundaryLine = "--" + boundary + "\r\n";
//         this.firstBoundary = ByteBuffer.wrap(firstBoundaryLine.getBytes(StandardCharsets.US_ASCII));
//         string middleBoundaryLine = "\r\n" + firstBoundaryLine;
//         this.middleBoundary = ByteBuffer.wrap(middleBoundaryLine.getBytes(StandardCharsets.US_ASCII));
//         string onlyBoundaryLine = "--" + boundary + "--\r\n";
//         this.onlyBoundary = ByteBuffer.wrap(onlyBoundaryLine.getBytes(StandardCharsets.US_ASCII));
//         string lastBoundaryLine = "\r\n" + onlyBoundaryLine;
//         this.lastBoundary = ByteBuffer.wrap(lastBoundaryLine.getBytes(StandardCharsets.US_ASCII));
//     }

//     private static string makeBoundary() {
//         Random random = new Random();
//         StringBuilder builder = new StringBuilder("FireflyHttpClientBoundary");
//         int length = builder.length();
//         while (builder.length() < length + 16) {
//             long rnd = random.nextLong();
//             builder.append(to!long(rnd < 0 ? -rnd : rnd, 36));
//         }
//         builder.setLength(length + 16);
//         return builder.toString();
//     }

//     /**
//      * <p>Adds a field part with the given {@code name} as field name, and the given
//      * {@code content} as part content.</p>
//      *
//      * @param name    the part name
//      * @param content the part content
//      * @param fields  the headers associated with this part
//      */
//     void addFieldPart(string name, ContentProvider content, HttpFields fields) {
//         addPart(new Part(name, null, "text/plain", content, fields));
//     }

//     /**
//      * <p>Adds a file part with the given {@code name} as field name, the given
//      * {@code fileName} as file name, and the given {@code content} as part content.</p>
//      *
//      * @param name     the part name
//      * @param fileName the file name associated to this part
//      * @param content  the part content
//      * @param fields   the headers associated with this part
//      */
//     void addFilePart(string name, string fileName, ContentProvider content, HttpFields fields) {
//         addPart(new Part(name, fileName, "application/octet-stream", content, fields));
//     }

//     private void addPart(Part part) {
//         parts.add(part);
//         version(HuntDebugMode)
//             tracef("Added %s", part);
//     }

//     override
//     void setListener(Listener listener) {
//         this.listener = listener;
//         if (closed.get())
//             this.length = calculateLength();
//     }

//     private long calculateLength() {
//         // Compute the length, if possible.
//         if (parts.isEmpty()) {
//             return onlyBoundary.remaining();
//         } else {
//             long result = 0;
//             for (int i = 0; i < parts.size(); ++i) {
//                 result += (i == 0) ? firstBoundary.remaining() : middleBoundary.remaining();
//                 Part part = parts.get(i);
//                 long partLength = part.length;
//                 result += partLength;
//                 if (partLength < 0) {
//                     result = -1;
//                     break;
//                 }
//             }
//             if (result > 0)
//                 result += lastBoundary.remaining();
//             return result;
//         }
//     }

//     override
//     long getLength() {
//         return length;
//     }

//     override
//     Iterator!ByteBuffer iterator() {
//         return new MultiPartIterator();
//     }

//     override
//     void close() {
//         closed.compareAndSet(false, true);
//     }

//     private static class Part {
//         private string name;
//         private string fileName;
//         private string contentType;
//         private ContentProvider content;
//         private HttpFields fields;
//         private ByteBuffer headers;
//         private long length;

//         private Part(string name, string fileName, string contentType, ContentProvider content, HttpFields fields) {
//             this.name = name;
//             this.fileName = fileName;
//             this.contentType = contentType;
//             this.content = content;
//             this.fields = fields;
//             this.headers = headers();
//             this.length = content.getLength() < 0 ? -1 : headers.remaining() + content.getLength();
//         }

//         private ByteBuffer headers() {
//             try {
//                 // Compute the Content-Disposition.
//                 string contentDisposition = "Content-Disposition: form-data; name=\"" + name + "\"";
//                 if (fileName != null)
//                     contentDisposition += "; filename=\"" + fileName + "\"";
//                 contentDisposition += "\r\n";

//                 // Compute the Content-Type.
//                 string contentType = fields == null ? null : fields.get(HttpHeader.CONTENT_TYPE);
//                 if (contentType == null) {
//                     if (content instanceof Typed)
//                         contentType = ((Typed) content).getContentType();
//                     else
//                         contentType = this.contentType;
//                 }
//                 contentType = "Content-Type: " + contentType + "\r\n";

//                 if (fields == null || fields.size() == 0) {
//                     string headers = contentDisposition;
//                     headers += contentType;
//                     headers += "\r\n";
//                     return ByteBuffer.wrap(headers.getBytes(StandardCharsets.UTF_8));
//                 }

//                 ByteArrayOutputStream buffer = new ByteArrayOutputStream((fields.size() + 1) * contentDisposition.length());
//                 buffer.write(contentDisposition.getBytes(StandardCharsets.UTF_8));
//                 buffer.write(contentType.getBytes(StandardCharsets.UTF_8));
//                 for (HttpField field : fields) {
//                     if (HttpHeader.CONTENT_TYPE.equals(field.getHeader()))
//                         continue;
//                     buffer.write(field.getName().getBytes(StandardCharsets.US_ASCII));
//                     buffer.write(COLON_SPACE_BYTES);
//                     string value = field.getValue();
//                     if (value != null)
//                         buffer.write(value.getBytes(StandardCharsets.UTF_8));
//                     buffer.write(CR_LF_BYTES);
//                 }
//                 buffer.write(CR_LF_BYTES);
//                 return ByteBuffer.wrap(buffer.toByteArray());
//             } catch (IOException x) {
//                 throw new CommonRuntimeException(x);
//             }
//         }

//         override
//         string toString() {
//             return format("%s@%x[name=%s,fileName=%s,length=%d,headers=%s]",
//                     typeof(this).stringof,
//                     toHash(),
//                     name,
//                     fileName,
//                     content.getLength(),
//                     fields);
//         }
//     }

//     private class MultiPartIterator : Iterator!ByteBuffer, Synchronizable, Callback, Closeable {
//         private Iterator!ByteBuffer iterator;
//         private int index;
//         private State state = State.FIRST_BOUNDARY;

//         override
//         bool hasNext() {
//             return state != State.COMPLETE;
//         }

//         override
//         ByteBuffer next() {
//             while (true) {
//                 switch (state) {
//                     case FIRST_BOUNDARY: {
//                         if (parts.isEmpty()) {
//                             state = State.COMPLETE;
//                             return onlyBoundary.slice();
//                         } else {
//                             state = State.HEADERS;
//                             return firstBoundary.slice();
//                         }
//                     }
//                     case HEADERS: {
//                         Part part = parts.get(index);
//                         ContentProvider content = part.content;
//                         if (content instanceof AsyncContentProvider)
//                             ((AsyncContentProvider) content).setListener(listener);
//                         iterator = content.iterator();
//                         state = State.CONTENT;
//                         return part.headers.slice();
//                     }
//                     case CONTENT: {
//                         if (iterator.hasNext())
//                             return iterator.next();
//                         ++index;
//                         if (index == parts.size())
//                             state = State.LAST_BOUNDARY;
//                         else
//                             state = State.MIDDLE_BOUNDARY;
//                         break;
//                     }
//                     case MIDDLE_BOUNDARY: {
//                         state = State.HEADERS;
//                         return middleBoundary.slice();
//                     }
//                     case LAST_BOUNDARY: {
//                         state = State.COMPLETE;
//                         return lastBoundary.slice();
//                     }
//                     case COMPLETE: {
//                         throw new NoSuchElementException();
//                     }
//                 }
//             }
//         }

//         override
//         Object getLock() {
//             if (iterator instanceof Synchronizable)
//                 return ((Synchronizable) iterator).getLock();
//             return this;
//         }

//         override
//         void succeeded() {
//             if (iterator instanceof Callback)
//                 ((Callback) iterator).succeeded();
//         }

//         override
//         void failed(Exception x) {
//             if (iterator instanceof Callback)
//                 ((Callback) iterator).failed(x);
//         }

//         override
//         void close() throws IOException {
//             if (iterator instanceof Closeable)
//                 ((Closeable) iterator).close();
//         }
//     }

//     private enum State {
//         FIRST_BOUNDARY, HEADERS, CONTENT, MIDDLE_BOUNDARY, LAST_BOUNDARY, COMPLETE
//     }
// }
