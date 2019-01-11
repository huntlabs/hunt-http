module hunt.http.codec.http.model.ByteBufferContentProvider;

// import hunt.collection.ByteBuffer;
// // import java.util.Iterator;
// // import java.util.NoSuchElementException;

// /**
//  * A {@link ContentProvider} for {@link ByteBuffer}s.
//  * <p>
//  * The position and limit of the {@link ByteBuffer}s passed to the constructor are not modified,
//  * and each invocation of the {@link #iterator()} method returns a {@link ByteBuffer#slice() slice}
//  * of the original {@link ByteBuffer}.
//  */
// class ByteBufferContentProvider :AbstractTypedContentProvider {
//     private ByteBuffer[] buffers;
//     private int length;

//     this(ByteBuffer[] buffers...) {
//         this("application/octet-stream", buffers);
//     }

//     this(string contentType, ByteBuffer[] buffers...) {
//         super(contentType);
//         this.buffers = buffers;
//         int length = 0;
//         foreach (ByteBuffer buffer ; buffers)
//             length += buffer.remaining();
//         this.length = length;
//     }

//     override
//     long getLength() {
//         return length;
//     }

//     override
//     Iterator!ByteBuffer iterator() {
//         return new Iterator!ByteBuffer() {
//             private int index;

//             override
//             bool hasNext() {
//                 return index < buffers.length;
//             }

//             override
//             ByteBuffer next() {
//                 try {
//                     ByteBuffer buffer = buffers[index];
//                     buffers[index] = buffer.slice();
//                     ++index;
//                     return buffer;
//                 } catch (ArrayIndexOutOfBoundsException x) {
//                     throw new NoSuchElementException();
//                 }
//             }

//             override
//             void remove() {
//                 throw new UnsupportedOperationException();
//             }
//         };
//     }
// }
