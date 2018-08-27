module hunt.http.codec.http.model.PathContentProvider;

import hunt.logger;


// import java.io.Closeable;
// import hunt.util.exception;
// import hunt.container.ByteBuffer;
// import java.nio.channels.SeekableByteChannel;
// import java.nio.file;
// import java.util.Iterator;
// import java.util.NoSuchElementException;

// /**
//  * <p>A {@link ContentProvider} for files using JDK 7's {@code java.nio.file} APIs.</p>
//  * <p>It is possible to specify, at the constructor, a buffer size used to read
//  * content from the stream, by default 4096 bytes.</p>
//  */
// class PathContentProvider :AbstractTypedContentProvider {

    

//     private Path filePath;
//     private long fileSize;
//     private int bufferSize;

//     this(Path filePath) throws IOException {
//         this(filePath, 4096);
//     }

//     this(Path filePath, int bufferSize) throws IOException {
//         this("application/octet-stream", filePath, bufferSize);
//     }

//     this(string contentType, Path filePath) throws IOException {
//         this(contentType, filePath, 4096);
//     }

//     this(string contentType, Path filePath, int bufferSize) throws IOException {
//         super(contentType);
//         if (!Files.isRegularFile(filePath))
//             throw new NoSuchFileException(filePath.toString());
//         if (!Files.isReadable(filePath))
//             throw new AccessDeniedException(filePath.toString());
//         this.filePath = filePath;
//         this.fileSize = Files.size(filePath);
//         this.bufferSize = bufferSize;
//     }

//     override
//     long getLength() {
//         return fileSize;
//     }

//     override
//     Iterator!ByteBuffer iterator() {
//         return new PathIterator();
//     }

//     private class PathIterator : Iterator!ByteBuffer, Closeable {
//         private SeekableByteChannel channel;
//         private long position;

//         override
//         bool hasNext() {
//             return position < getLength();
//         }

//         override
//         ByteBuffer next() {
//             try {
//                 if (channel == null) {
//                     channel = Files.newByteChannel(filePath, StandardOpenOption.READ);
//                     version(HuntDebugMode)
//                         tracef("Opened file %s", filePath);
//                 }

//                 ByteBuffer buffer = ByteBuffer.allocate(bufferSize);
//                 int read = channel.read(buffer);
//                 if (read < 0)
//                     throw new NoSuchElementException();

//                 version(HuntDebugMode)
//                     tracef("Read %s bytes from %s", read, filePath);

//                 position += read;

//                 buffer.flip();
//                 return buffer;
//             } catch (NoSuchElementException x) {
//                 close();
//                 throw x;
//             } catch (Exception x) {
//                 close();
//                 throw (NoSuchElementException) new NoSuchElementException().initCause(x);
//             }
//         }

//         override
//         void close() {
//             try {
//                 if (channel != null)
//                     channel.close();
//             } catch (Exception x) {
//                 LOG.error("channel close error", x);
//             }
//         }
//     }
// }
