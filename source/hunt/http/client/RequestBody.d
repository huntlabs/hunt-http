
deprecated("Using hunt.http.HttpBody instead.")
module hunt.http.client.RequestBody;

import hunt.http.HttpBody;

deprecated("Using HttpBody instead.")
alias RequestBody = HttpBody;


// import hunt.http.HttpOutputStream;
// import hunt.io.HeapByteBuffer;
// import hunt.io.ByteBuffer;
// import hunt.io.BufferUtils;

// import hunt.Exceptions;
// import hunt.logging;
// import hunt.util.MimeType;
// import hunt.util.MimeTypeUtils;

// import std.range;
// import std.file;
// import std.path;
// import std.range;
// import std.stdio;

// /** 
//  * 
//  */
// abstract class RequestBody {

// 	string contentType();

//     /**
//      * Returns the number of bytes that will be written to {@code sink} in a call to {@link #writeTo},
//      * or -1 if that count is unknown.
//      */
// 	long contentLength() {
// 		return -1;
// 	}

//     /** Writes the content of this request to {@code sink}. */
//     void writeTo(HttpOutputStream sink);

	
//     /**
//      * Returns a new request body that transmits {@code content}. If {@code contentType} is non-null
//      * and lacks a charset, this will use UTF-8.
//      */
//     static RequestBody create(string contentType, string content) {
//         // Charset charset = UTF_8;
//         if (contentType !is null) {
//             // charset = contentType.charset();
// 			string charset = new MimeType(contentType).getCharset();
//             if (charset.empty()) {
//                 // charset = UTF_8;
//                 contentType = contentType ~ "; charset=utf-8";
//             }
//         }
//         byte[] bytes = cast(byte[])content; // content.getBytes(charset);
//         return create(contentType, bytes);
//     }

	
//     /** Returns a new request body that transmits {@code content}. */
//     static RequestBody create(string contentType, byte[] content) {
//         return create(contentType, content, 0, cast(int)content.length);
//     }

//     /** Returns a new request body that transmits {@code content}. */
//     static RequestBody create(string type, byte[] content,
//             int offset, int byteCount) {

//         if (content.empty()) throw new NullPointerException("content is null");
//         // Util.checkOffsetAndCount(content.length, offset, byteCount);
// 		assert(offset + byteCount <= content.length);

//         return new class RequestBody {

//             override string contentType() {
//                 return type;
//             }

//             override long contentLength() {
//                 return byteCount;
//             }

//             override void writeTo(HttpOutputStream sink) {
//                 sink.write(content, offset, byteCount);
//             }
//         };
//     }

//     /** Returns a new request body that transmits the content of {@code file}. */
//     static RequestBody createFromFile(string type, string fileName) {
//         if (fileName.empty()) throw new NullPointerException("fileName is null");
		
// 		string rootPath = dirName(thisExePath);
// 		string abslutePath = buildPath(rootPath, fileName);
// 		version(HUNT_HTTP_DEBUG) info("generate request body from file: ", abslutePath);
// 		if(!abslutePath.exists) throw new FileNotFoundException(fileName);

// 		DirEntry entry = DirEntry(abslutePath);
// 		if(entry.isDir()) throw new FileException("Can't handle a direcotry: ", abslutePath);

// 		long total = cast(long)entry.size();
// 		if(total > 10*1024*1024) {
// 			// throw new FileException("The file is too big to upload (< 10MB).");
// 			debug warning("uploading a big file: %d MB", total/1024/1024);
// 		}

//         return new class RequestBody {
//             override string contentType() {
//                 return type;
//             }

//             override long contentLength() {
//                 return total;
//             }

// 			override void writeTo(HttpOutputStream sink)  {
// 				version(HUNT_HTTP_DEBUG) infof("loading data from: %s, size: %d", abslutePath, total);
// 				enum MaxBufferSize = 16*1024;
// 				ubyte[] buffer;
				
// 				File f = File(abslutePath, "r");
// 				scope(exit) f.close();

// 				size_t remaining = cast(size_t)total;
// 				while(remaining > 0 && !f.eof()) {

// 					if(remaining > MaxBufferSize) 
// 						buffer = new ubyte[MaxBufferSize];
// 					else 
// 						buffer = new ubyte[remaining];
// 					ubyte[] data = f.rawRead(buffer);
                    
//                     if(data.length > 0) {
// 					    sink.write(cast(byte[])data);
//                         remaining -= cast(int)data.length;
//                     }
//                     version(HUNT_HTTP_DEBUG_MORE) {
//                         tracef("read: %s, remaining: %d, eof: %s", 
//                             data.length, remaining, f.eof());
//                     }
// 				}
// 			}
//         };
//     }		
// }