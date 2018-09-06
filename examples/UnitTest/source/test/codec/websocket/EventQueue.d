module test.codec.websocket.EventQueue;

// import java.util.concurrent.LinkedBlockingQueue;
// import java.util.concurrent.TimeUnit;
// import java.util.concurrent.TimeoutException;
// import java.util.concurrent.locks.Condition;
// import java.util.concurrent.locks.ReentrantLock;

/**
 * Event Queue for capturing potential events within a testing scenario.
 *
 * @param <E> the type of entry in this EventQueue
 */

// public class EventQueue<E> extends LinkedBlockingQueue<E> {
    
//     public static final bool DEBUG = false;
//     private static final long DEBUG_START = System.currentTimeMillis();
//     private final ReentrantLock lock = new ReentrantLock();
//     private final Condition countReached = lock.newCondition();
//     private int goalCount = Integer.MAX_VALUE;

//     override
//     public bool add(E o) {
//         debug("add(%s)", o);
//         lock.lock();
//         try {
//             bool ret = super.add(o);
//             debug("added: %s", o);
//             goalCheck();
//             return ret;
//         } finally {
//             lock.unlock();
//         }
//     }

//     /**
//      * Await a specific event count
//      *
//      * @param expectedEventCount the number of events to wait for
//      * @param timeoutDuration    the timeout duration
//      * @param timeoutUnit        the timeout unit
//      * @throws TimeoutException     if timeout while waiting for the event count
//      * @throws InterruptedException if await was interrupted
//      */
//     public void awaitEventCount(int expectedEventCount, int timeoutDuration, TimeUnit timeoutUnit) throws TimeoutException, InterruptedException {
//         debug("awaitEventCount(%d,%d,%s)", expectedEventCount, timeoutDuration, timeoutUnit);
//         lock.lock();
//         try {
//             goalCount = expectedEventCount;
//             if (goalCheck())
//                 return;
//             debug("awaiting countReached");
//             if (!countReached.await(timeoutDuration, timeoutUnit)) {
//                 throw new TimeoutException(string.format("Timeout (%d %s) waiting for %d events (found %d)",
//                         timeoutDuration, timeoutUnit.name(), expectedEventCount, size()));
//             }
//         } finally {
//             lock.unlock();
//         }
//     }

//     private void debug(string format, Object... args) {
//         if (DEBUG) {
//             StringBuilder fmt2 = new StringBuilder();
//             fmt2.append(string.format("%,6d [EventQueue|", System.currentTimeMillis() - DEBUG_START));
//             fmt2.append(Thread.currentThread().getName());
//             fmt2.append("] ").append(string.format(format, args));
//             System.err.println(fmt2);
//         }
//     }

//     private bool goalCheck() {
//         if (size() >= goalCount) {
//             countReached.signalAll();
//             return true;
//         }
//         return false;
//     }

//     override
//     public bool offer(E o) {
//         debug("offer(%s)", o);
//         lock.lock();
//         try {
//             bool ret = super.offer(o);
//             debug("offered: %s", o);
//             goalCheck();
//             return ret;
//         } finally {
//             lock.unlock();
//         }
//     }

//     /**
//      * Shutdown the queue.
//      */
//     public void shutdown() {
//         /* nothing to do */
//     }
// }