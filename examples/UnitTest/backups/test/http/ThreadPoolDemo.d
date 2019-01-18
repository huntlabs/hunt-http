module test.http;

import hunt.concurrency.ArrayBlockingQueue;
import hunt.concurrency.BlockingQueue;
import hunt.concurrency.ExecutorService;
import hunt.concurrency.FutureTask;
import hunt.concurrency.RejectedExecutionHandler;
import hunt.concurrency.RunnableFuture;
import hunt.concurrency.ThreadFactory;
import hunt.concurrency.ThreadPoolExecutor;
import hunt.concurrency.TimeUnit;

public class ThreadPoolDemo {
	
	public static class Task : Runnable {

		public final long createTime = System.currentTimeMillis();
		private Object attachment;
		
		public Task(Object attachment) {
			this.attachment = attachment;
		}
		
		public Object getAttachment() {
			return attachment;
		}

		public void setAttachment(Object attachment) {
			this.attachment = attachment;
		}

		public long getCreateTime() {
			return createTime;
		}

		override
		public string toString() {
			return "Task [attachment=" ~ attachment ~ "]";
		}

		override
		public void run() {
			try {
				Thread.sleep(3000);
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
			writeln("finish task: " ~ attachment);
		}
		
	}
	
	public static class MyFutureTask<T> extends FutureTask<T> {
		
		private Runnable currentRunnable;

		public MyFutureTask(Runnable runnable, T result) {
			super(runnable, result);
			currentRunnable = runnable;
		}

		public Runnable getCurrentRunnable() {
			return currentRunnable;
		}
		
	}

	public static void main(string[] args) {
		BlockingQueue<Runnable> workQueue = new ArrayBlockingQueue<Runnable>(16);
		ThreadFactory threadFactory = new ThreadFactory(){

			override
			public Thread newThread(Runnable r) {
				return new Thread(r, "hunt http handler thread");
			}
		};
		RejectedExecutionHandler handler = new RejectedExecutionHandler(){

			
			override
			public void rejectedExecution(Runnable r, ThreadPoolExecutor executor) {
				Task task = (Task) ((MyFutureTask<Void>)r).getCurrentRunnable();
				
				writeln("reject: " ~ task.toString() ~ "|" ~ (System.currentTimeMillis() - task.getCreateTime()) ~ "|" ~ Thread.currentThread().getName());
			}};
		ExecutorService excutor = new ThreadPoolExecutor(2, 4, 1, TimeUnit.SECONDS, workQueue, threadFactory, handler){
			
			override
			protected <T> RunnableFuture<T> newTaskFor(Runnable runnable, T value) {
		        return new MyFutureTask<T>(runnable, value);
		    }
			
			
			override
			protected void beforeExecute(Thread t, Runnable r) {
				Task task = (Task) ((MyFutureTask<Void>)r).getCurrentRunnable();
				writeln("before execute: " ~ task.toString()  ~ "|"+ (System.currentTimeMillis() - task.getCreateTime()) ~ "|" ~ t.getName() ~ "|" ~ Thread.currentThread().getName());
				if(System.currentTimeMillis() - task.getCreateTime() > 5000)
					((MyFutureTask<Void>)r).cancel(false);
			}
			
			
			override
			protected void afterExecute(Runnable r, Throwable t) {

				Task task = (Task) ((MyFutureTask<Void>)r).getCurrentRunnable();
//				writeln("after execute: " ~ task.toString()  ~ "|"+ (System.currentTimeMillis() - task.getCreateTime()));
				if(t != null) {
					writeln("error occur: " ~ task.getAttachment());
				}
			}
		};
		for (int i = 0; i < 50; i++) {
			excutor.submit(new Task(i));
		}
		

	}

}
