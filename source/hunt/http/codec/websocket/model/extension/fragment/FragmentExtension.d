module hunt.http.codec.websocket.model.extension.fragment;

import hunt.http.codec.websocket.frame.DataFrame;
import hunt.http.codec.websocket.frame.Frame;
import hunt.http.codec.websocket.model.ExtensionConfig;
import hunt.http.codec.websocket.model.OpCode;
import hunt.http.codec.websocket.model.extension.AbstractExtension;
import hunt.util.functional;
// import hunt.http.utils.concurrent.IteratingCallback;
import hunt.logging;
import hunt.container;


/**
 * Fragment Extension
 */
// class FragmentExtension : AbstractExtension {


//     private Queue!(FrameEntry) entries;
//     private IteratingCallback flusher;
//     private int maxLength;

//     this() {
//         entries = new ArrayDeque!(FrameEntry)();
//         flusher = new Flusher();
//         start();
//     }

//     override
//     string getName() {
//         return "fragment";
//     }

//     override
//     void incomingFrame(Frame frame) {
//         nextIncomingFrame(frame);
//     }

//     override
//     void outgoingFrame(Frame frame, Callback callback) {
//         ByteBuffer payload = frame.getPayload();
//         int length = payload !is null ? payload.remaining() : 0;
//         if (OpCode.isControlFrame(frame.getOpCode()) || maxLength <= 0 || length <= maxLength) {
//             nextOutgoingFrame(frame, callback);
//             return;
//         }

//         FrameEntry entry = new FrameEntry(frame, callback);
//         version(HuntDebugMode)
//             tracef("Queuing %s", entry);
//         offerEntry(entry);
//         flusher.iterate();
//     }

//     override
//     void setConfig(ExtensionConfig config) {
//         super.setConfig(config);
//         maxLength = config.getParameter("maxLength", -1);
//     }

//     private void offerEntry(FrameEntry entry) {
//         synchronized (this) {
//             entries.offer(entry);
//         }
//     }

//     private FrameEntry pollEntry() {
//         synchronized (this) {
//             return entries.poll();
//         }
//     }

//     override
//     protected void init() {

//     }

//     override
//     protected void destroy() {

//     }

//     private static class FrameEntry {
//         private final Frame frame;
//         private final Callback callback;

//         private this(Frame frame, Callback callback) {
//             this.frame = frame;
//             this.callback = callback;
//         }

//         override
//         string toString() {
//             return frame.toString();
//         }
//     }

//     private class Flusher : IteratingCallback {
//         private FrameEntry current;
//         private bool finished = true;

//         override
//         protected Action process() {
//             if (finished) {
//                 current = pollEntry();
//                 tracef("Processing %s", current);
//                 if (current is null)
//                     return Action.IDLE;
//                 fragment(current, true);
//             } else {
//                 fragment(current, false);
//             }
//             return Action.SCHEDULED;
//         }

//         private void fragment(FrameEntry entry, bool first) {
//             Frame frame = entry.frame;
//             ByteBuffer payload = frame.getPayload();
//             int remaining = payload.remaining();
//             int length = Math.min(remaining, maxLength);
//             finished = length == remaining;

//             bool continuation = frame.getType().isContinuation() || !first;
//             DataFrame fragment = new DataFrame(frame, continuation);
//             bool fin = frame.isFin() && finished;
//             fragment.setFin(fin);

//             int limit = payload.limit();
//             int newLimit = payload.position() + length;
//             payload.limit(newLimit);
//             ByteBuffer payloadFragment = payload.slice();
//             payload.limit(limit);
//             fragment.setPayload(payloadFragment);
//             version(HuntDebugMode)
//                 tracef("Fragmented %s->%s", frame, fragment);
//             payload.position(newLimit);

//             nextOutgoingFrame(fragment, this);
//         }

//         override
//         protected void onCompleteSuccess() {
//             // This IteratingCallback never completes.
//         }

//         override
//         protected void onCompleteFailure(Throwable x) {
//             // This IteratingCallback never fails.
//             // The callback are those provided by WriteCallback (implemented
//             // below) and even in case of writeFailed() we call succeeded().
//         }

//         override
//         void succeeded() {
//             // Notify first then call succeeded(), otherwise
//             // write callbacks may be invoked out of order.
//             notifyCallbackSuccess(current.callback);
//             super.succeeded();
//         }

//         override
//         void failed(Throwable x) {
//             // Notify first, the call succeeded() to drain the queue.
//             // We don't want to call failed(x) because that will put
//             // this flusher into a final state that cannot be exited,
//             // and the failure of a frame may not mean that the whole
//             // connection is now invalid.
//             notifyCallbackFailure(current.callback, x);
//             succeeded();
//         }

//         private void notifyCallbackSuccess(Callback callback) {
//             try {
//                 if (callback !is null)
//                     callback.succeeded();
//             } catch (Throwable x) {
//                 version(HuntDebugMode)
//                     tracef("Exception while notifying success of callback " ~ callback, x);
//             }
//         }

//         private void notifyCallbackFailure(Callback callback, Throwable failure) {
//             try {
//                 if (callback !is null)
//                     callback.failed(failure);
//             } catch (Throwable x) {
//                 version(HuntDebugMode)
//                     tracef("Exception while notifying failure of callback " ~ callback, x);
//             }
//         }
//     }
// }
