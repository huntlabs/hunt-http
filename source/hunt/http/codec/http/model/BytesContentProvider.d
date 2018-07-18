module hunt.http.codec.http.model.BytesContentProvider;

// import hunt.container.ByteBuffer;
// import java.util.Iterator;
// import java.util.NoSuchElementException;

// /**
//  * A {@link ContentProvider} for byte arrays.
//  */
// class BytesContentProvider :AbstractTypedContentProvider {
//     private byte[][] bytes;
//     private long length;

//     this(byte[]... bytes) {
//         this("application/octet-stream", bytes);
//     }

//     this(string contentType, byte[]... bytes) {
//         super(contentType);
//         this.bytes = bytes;
//         long length = 0;
//         for (byte[] buffer : bytes)
//             length += buffer.length;
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
//                 return index < bytes.length;
//             }

//             override
//             ByteBuffer next() {
//                 try {
//                     return ByteBuffer.wrap(bytes[index++]);
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
